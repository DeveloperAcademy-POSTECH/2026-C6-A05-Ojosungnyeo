//
//  HomeFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct HomeFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var isMenuPresented = false
        var isWithdrawalConfirmationPresented = false
        var isWithdrawing = false
        var withdrawalErrorMessage: String?
    }

    enum Action {
        case exploreTripsButtonTapped
        case menuButtonTapped
        case menuDismissed
        case logoutButtonTapped
        case withdrawButtonTapped
        case withdrawalConfirmationDismissed
        case withdrawalConfirmed
        case withdrawalResponse(Result<Void, Error>)
        case withdrawalErrorDismissed
    }

    @Dependency(\.appleSignInClient) var appleSignInClient
    @Dependency(\.authClient) var authClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .exploreTripsButtonTapped:
                return .none
            case .menuButtonTapped:
                state.isMenuPresented.toggle()
                return .none
            case .menuDismissed:
                state.isMenuPresented = false
                return .none
            case .logoutButtonTapped:
                state.isMenuPresented = false
                return .run { _ in
                    try await authClient.signOut()
                }
            case .withdrawButtonTapped:
                state.isMenuPresented = false
                state.isWithdrawalConfirmationPresented = true
                return .none
            case .withdrawalConfirmationDismissed:
                state.isWithdrawalConfirmationPresented = false
                return .none
            case .withdrawalConfirmed:
                guard !state.isWithdrawing else { return .none }
                state.isWithdrawalConfirmationPresented = false
                state.isWithdrawing = true
                state.withdrawalErrorMessage = nil

                return .run { send in
                    do {
                        let appleResult = try await appleSignInClient.signIn()
                        _ = try await authClient.signInWithApple(appleResult)
                        try await authClient.deleteAccount(appleResult.authorizationCode)
                        await send(.withdrawalResponse(.success(())))
                    } catch {
                        await send(.withdrawalResponse(.failure(error)))
                    }
                }
            case .withdrawalResponse(.success):
                state.isWithdrawing = false
                return .none
            case let .withdrawalResponse(.failure(error)):
                state.isWithdrawing = false
                if error as? AppleSignInError == .canceled {
                    return .none
                }

                switch error as? AuthClientError {
                case .firebaseNotConfigured:
                    state.withdrawalErrorMessage = "Firebase 설정 파일을 확인해 주세요."
                case .userNotFound:
                    state.withdrawalErrorMessage = "로그인된 계정을 찾을 수 없어요."
                case .recentLoginRequired:
                    state.withdrawalErrorMessage = "보안을 위해 다시 로그인한 뒤 시도해 주세요."
                case .networkUnavailable:
                    state.withdrawalErrorMessage = "네트워크 연결을 확인해 주세요."
                case let .accountDeletionFailed(code, message):
                    state.withdrawalErrorMessage = "Firebase 오류 \(code): \(message)"
                default:
                    state.withdrawalErrorMessage = "탈퇴에 실패했어요. 다시 시도해 주세요."
                }
                return .none
            case .withdrawalErrorDismissed:
                state.withdrawalErrorMessage = nil
                return .none
            }
        }
    }
}
