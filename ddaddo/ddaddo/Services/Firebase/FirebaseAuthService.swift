//
//  FirebaseAuthService.swift
//  ddaddo
//
//  Created by sun on 10/29/26.
//

import FirebaseAuth
import Foundation

enum FirebaseAuthService {
    static func authStateChanges() -> AsyncStream<AuthenticatedUser?> {
        guard FirebaseService.isConfigured else {
            return AsyncStream { continuation in
                continuation.yield(nil)
                continuation.finish()
            }
        }

        return AsyncStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                continuation.yield(user.map { AuthenticatedUser(id: $0.uid) })
            }

            continuation.onTermination = { _ in
                Task { @MainActor in
                    Auth.auth().removeStateDidChangeListener(handle)
                }
            }
        }
    }

    static func signInWithApple(_ result: AppleSignInResult) async throws -> AuthenticatedUser {
        guard FirebaseService.isConfigured else {
            throw AuthClientError.firebaseNotConfigured
        }
        guard let identityToken = String(data: result.identityToken, encoding: .utf8) else {
            throw AuthClientError.invalidIdentityToken
        }

        var fullName: PersonNameComponents?
        if result.givenName != nil || result.familyName != nil {
            var components = PersonNameComponents()
            components.givenName = result.givenName
            components.familyName = result.familyName
            fullName = components
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: identityToken,
            rawNonce: result.rawNonce,
            fullName: fullName
        )
        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            return AuthenticatedUser(id: authResult.user.uid)
        } catch {
            let firebaseError = error as NSError
            let errorCode = firebaseError.code

            switch AuthErrorCode(rawValue: errorCode) {
            case .operationNotAllowed:
                throw AuthClientError.appleProviderDisabled
            case .invalidCredential:
                throw AuthClientError.invalidAppleCredential
            case .networkError:
                throw AuthClientError.networkUnavailable
            default:
                let message = serverMessage(from: firebaseError)
                    ?? firebaseError.localizedDescription
                if message.contains("CONFIGURATION_NOT_FOUND") {
                    throw AuthClientError.firebaseAuthenticationNotConfigured
                }
                throw AuthClientError.signInFailed(code: errorCode, message: message)
            }
        }
    }

    static func signOut() throws {
        guard FirebaseService.isConfigured else { return }
        try Auth.auth().signOut()
    }

    static func deleteAccount(authorizationCode: Data?) async throws {
        guard FirebaseService.isConfigured else {
            throw AuthClientError.firebaseNotConfigured
        }
        guard let user = Auth.auth().currentUser else {
            throw AuthClientError.userNotFound
        }

        do {
            if
                let authorizationCode,
                let authorizationCodeString = String(
                    data: authorizationCode,
                    encoding: .utf8
                )
            {
                try await Auth.auth().revokeToken(
                    withAuthorizationCode: authorizationCodeString
                )
            }

            try await user.delete()
        } catch {
            let firebaseError = error as NSError
            if AuthErrorCode(rawValue: firebaseError.code) == .requiresRecentLogin {
                throw AuthClientError.recentLoginRequired
            }

            let message = serverMessage(from: firebaseError)
                ?? firebaseError.localizedDescription
            throw AuthClientError.accountDeletionFailed(
                code: firebaseError.code,
                message: message
            )
        }
    }

    private static func serverMessage(from error: NSError) -> String? {
        if let response = error.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"]
            as? [String: Any],
           let message = response["message"] as? String {
            return message
        }
        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return serverMessage(from: underlyingError)
                ?? underlyingError.localizedDescription
        }
        return nil
    }
}
