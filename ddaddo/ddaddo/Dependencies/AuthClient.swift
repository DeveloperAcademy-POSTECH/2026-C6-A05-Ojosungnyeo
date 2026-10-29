//
//  AuthClient.swift
//  ddaddo
//
//  Created by sun on 10/29/26.
//

import ComposableArchitecture
import Foundation

enum AuthClientError: Error, Equatable {
    case firebaseNotConfigured
    case firebaseAuthenticationNotConfigured
    case invalidIdentityToken
    case appleProviderDisabled
    case invalidAppleCredential
    case networkUnavailable
    case userNotFound
    case recentLoginRequired
    case accountDeletionFailed(code: Int, message: String)
    case signInFailed(code: Int, message: String)
}

struct AuthClient: DependencyKey, Sendable {
    var authStateChanges: @MainActor @Sendable () -> AsyncStream<AuthenticatedUser?>
    var signInWithApple: @MainActor @Sendable (AppleSignInResult) async throws -> AuthenticatedUser
    var signOut: @MainActor @Sendable () throws -> Void
    var deleteAccount: @MainActor @Sendable (Data?) async throws -> Void

    static let liveValue = Self(
        authStateChanges: {
            FirebaseAuthService.authStateChanges()
        },
        signInWithApple: { result in
            try await FirebaseAuthService.signInWithApple(result)
        },
        signOut: {
            try FirebaseAuthService.signOut()
        },
        deleteAccount: { authorizationCode in
            try await FirebaseAuthService.deleteAccount(
                authorizationCode: authorizationCode
            )
        }
    )

    static let testValue = Self(
        authStateChanges: {
            AsyncStream { continuation in
                continuation.yield(nil)
                continuation.finish()
            }
        },
        signInWithApple: { _ in
            throw AuthClientError.firebaseNotConfigured
        },
        signOut: {},
        deleteAccount: { _ in }
    )
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
