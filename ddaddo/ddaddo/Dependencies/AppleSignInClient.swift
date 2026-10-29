//
//  AppleSignInClient.swift
//  ddaddo
//
//  Created by sun on 10/28/26.
//

import AuthenticationServices
import ComposableArchitecture
import CryptoKit
import Security
import UIKit

struct AppleSignInResult: Equatable, Sendable {
    let userIdentifier: String
    let identityToken: Data
    let authorizationCode: Data?
    let rawNonce: String
    let givenName: String?
    let familyName: String?
}

enum AppleSignInError: Error, Equatable {
    case canceled
    case invalidCredential
    case invalidNonce
    case unavailablePresentationAnchor
    case authorizationFailed(code: Int)
}

struct AppleSignInClient: DependencyKey, Sendable {
    var signIn: @MainActor @Sendable () async throws -> AppleSignInResult

    static let liveValue = Self(
        signIn: {
            let rawNonce = try makeRandomNonce()
            let performer = AppleAuthorizationPerformer(rawNonce: rawNonce)
            return try await performer.signIn()
        }
    )

    static let testValue = Self(
        signIn: { throw AppleSignInError.authorizationFailed(code: -1) }
    )
}

extension DependencyValues {
    var appleSignInClient: AppleSignInClient {
        get { self[AppleSignInClient.self] }
        set { self[AppleSignInClient.self] = newValue }
    }
}

@MainActor
private final class AppleAuthorizationPerformer: NSObject {
    private let rawNonce: String
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    init(rawNonce: String) {
        self.rawNonce = rawNonce
    }

    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(rawNonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(with result: Result<AppleSignInResult, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

extension AppleAuthorizationPerformer: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let identityToken = credential.identityToken
        else {
            finish(with: .failure(AppleSignInError.invalidCredential))
            return
        }

        finish(
            with: .success(
                AppleSignInResult(
                    userIdentifier: credential.user,
                    identityToken: identityToken,
                    authorizationCode: credential.authorizationCode,
                    rawNonce: rawNonce,
                    givenName: credential.fullName?.givenName,
                    familyName: credential.fullName?.familyName
                )
            )
        )
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if (error as? ASAuthorizationError)?.code == .canceled {
            finish(with: .failure(AppleSignInError.canceled))
        } else {
            finish(
                with: .failure(
                    AppleSignInError.authorizationFailed(code: (error as NSError).code)
                )
            )
        }
    }
}

extension AppleAuthorizationPerformer: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? ASPresentationAnchor()
    }
}

private func makeRandomNonce(length: Int = 32) throws -> String {
    let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        var random: UInt8 = 0
        guard SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess else {
            throw AppleSignInError.invalidNonce
        }

        if Int(random) < characters.count {
            result.append(characters[Int(random)])
            remainingLength -= 1
        }
    }

    return result
}

private func sha256(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
}
