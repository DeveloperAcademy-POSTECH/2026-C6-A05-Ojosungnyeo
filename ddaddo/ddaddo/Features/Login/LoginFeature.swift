//
//  LoginFeature.swift
//  ddaddo
//
//  Created by sun on 10/28/26.
//

import ComposableArchitecture

struct LoginFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var isSigningIn = false
        var errorMessage: String?
    }

    enum Action {
        case appleSignInButtonTapped
        case signInResponse(Result<AuthenticatedUser, Error>)
        case delegate(Delegate)

        enum Delegate {
            case signInSucceeded
        }
    }

    @Dependency(\.appleSignInClient) var appleSignInClient
    @Dependency(\.authClient) var authClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .appleSignInButtonTapped:
                guard !state.isSigningIn else { return .none }
                state.isSigningIn = true
                state.errorMessage = nil

                return .run { send in
                    do {
                        let appleResult = try await appleSignInClient.signIn()
                        let user = try await authClient.signInWithApple(appleResult)
                        await send(.signInResponse(.success(user)))
                    } catch {
                        await send(.signInResponse(.failure(error)))
                    }
                }

            case .signInResponse(.success):
                state.isSigningIn = false
                return .send(.delegate(.signInSucceeded))

            case let .signInResponse(.failure(error)):
                state.isSigningIn = false

                switch error as? AuthClientError {
                case .firebaseNotConfigured:
                    state.errorMessage = "Firebase 설정 파일을 확인해 주세요."
                case .firebaseAuthenticationNotConfigured:
                    state.errorMessage = "Firebase Console에서 Authentication과 Apple 로그인을 활성화해 주세요."
                case .invalidIdentityToken, .invalidAppleCredential:
                    state.errorMessage = "Apple 인증 정보가 올바르지 않아요. 다시 시도해 주세요."
                case .appleProviderDisabled:
                    state.errorMessage = "Firebase Authentication에서 Apple 로그인을 활성화해 주세요."
                case .networkUnavailable:
                    state.errorMessage = "네트워크 연결을 확인한 뒤 다시 시도해 주세요."
                case let .signInFailed(code, message):
                    state.errorMessage = "Firebase 오류 \(code): \(message)"
                case nil:
                    if case let .authorizationFailed(code) = error as? AppleSignInError {
                        state.errorMessage = "Apple 인증 요청에 실패했어요. (Apple 오류 \(code))"
                    } else if error as? AppleSignInError != .canceled {
                        state.errorMessage = "Apple 로그인에 실패했어요. 다시 시도해 주세요."
                    }
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
