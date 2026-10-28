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
        case appleSignInResponse(Result<AppleSignInResult, Error>)
        case delegate(Delegate)

        enum Delegate {
            case signInSucceeded
        }
    }

    @Dependency(\.appleSignInClient) var appleSignInClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .appleSignInButtonTapped:
                guard !state.isSigningIn else { return .none }
                state.isSigningIn = true
                state.errorMessage = nil

                return .run { send in
                    do {
                        let result = try await appleSignInClient.signIn()
                        await send(.appleSignInResponse(.success(result)))
                    } catch {
                        await send(.appleSignInResponse(.failure(error)))
                    }
                }

            case let .appleSignInResponse(.success(result)):
                _ = result
                state.isSigningIn = false
                return .send(.delegate(.signInSucceeded))

            case let .appleSignInResponse(.failure(error)):
                state.isSigningIn = false

                if error as? AppleSignInError != .canceled {
                    state.errorMessage = "Apple 로그인에 실패했어요. 다시 시도해 주세요."
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
