//
//  SettingsFeature.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

import ComposableArchitecture
import Foundation

struct SettingsFeature: Reducer {
    enum Screen: Equatable { case settings, nickname, account, withdrawal, complete }

    @ObservableState
    struct State: Equatable {
        var userID = ""
        var screen = Screen.settings
        var nickname = ""
        var nicknameDraft = ""
        var isNotificationEnabled = true
        var isSavingNickname = false
        var nicknameError: String?
        var hasAcknowledgedWithdrawal = false
        var isLogoutAlertPresented = false
        var isWithdrawalAlertPresented = false
        var isWithdrawing = false
        var errorMessage: String?
    }

    @CasePathable
    enum Action {
        case onAppear
        case nicknameLoaded(Result<String, Error>)
        case backButtonTapped
        case nicknameEditTapped
        case accountManagementTapped
        case notificationToggled(Bool)
        case nicknameChanged(String)
        case saveNicknameTapped
        case nicknameSaved(Result<Void, Error>)
        case logoutTapped
        case logoutAlertDismissed
        case logoutConfirmed
        case withdrawalTapped
        case withdrawalAcknowledgementToggled
        case withdrawalCancelTapped
        case withdrawalProceedTapped
        case withdrawalAlertDismissed
        case withdrawalConfirmed
        case withdrawalResponse(Result<Void, Error>)
        case errorDismissed
        case returnToLoginTapped
        case delegate(Delegate)
    }

    enum Delegate { case dismiss, withdrawalStarted, returnToLogin }

    @Dependency(\.nicknameClient) var nicknameClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.appleSignInClient) var appleSignInClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.userID.isEmpty, state.nickname.isEmpty else { return .none }
                let userID = state.userID
                return .run { send in
                    await send(.nicknameLoaded(Result { try await nicknameClient.fetchNickname(userID) }))
                }
            case let .nicknameLoaded(.success(nickname)):
                state.nickname = nickname
                state.nicknameDraft = nickname
                return .none
            case .nicknameLoaded(.failure):
                state.errorMessage = "닉네임을 불러오지 못했어요."
                return .none
            case .backButtonTapped:
                switch state.screen {
                case .settings: return .send(.delegate(.dismiss))
                case .nickname, .account: state.screen = .settings
                case .withdrawal: state.screen = .account
                case .complete: break
                }
                return .none
            case .nicknameEditTapped:
                state.nicknameDraft = state.nickname
                state.nicknameError = nil
                state.screen = .nickname
                return .none
            case .accountManagementTapped:
                state.screen = .account
                return .none
            case let .notificationToggled(value):
                state.isNotificationEnabled = value
                return .none
            case let .nicknameChanged(value):
                state.nicknameDraft = String(value.prefix(10))
                state.nicknameError = nil
                return .none
            case .saveNicknameTapped:
                let value = state.nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard (2...10).contains(value.count), value != state.nickname, !state.isSavingNickname else { return .none }
                state.isSavingNickname = true
                let userID = state.userID
                return .run { send in
                    await send(.nicknameSaved(Result { try await nicknameClient.saveNickname(userID, value) }))
                }
            case .nicknameSaved(.success):
                state.isSavingNickname = false
                state.nickname = state.nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                state.screen = .settings
                return .none
            case let .nicknameSaved(.failure(error)):
                state.isSavingNickname = false
                state.nicknameError = error as? NicknameClientError == .duplicateNickname
                    ? "중복된 닉네임입니다. 다른 닉네임을 입력해 주세요."
                    : "닉네임을 변경하지 못했어요."
                return .none
            case .logoutTapped:
                state.isLogoutAlertPresented = true
                return .none
            case .logoutAlertDismissed:
                state.isLogoutAlertPresented = false
                return .none
            case .logoutConfirmed:
                state.isLogoutAlertPresented = false
                return .run { _ in try await authClient.signOut() }
            case .withdrawalTapped:
                state.hasAcknowledgedWithdrawal = false
                state.screen = .withdrawal
                return .none
            case .withdrawalAcknowledgementToggled:
                state.hasAcknowledgedWithdrawal.toggle()
                return .none
            case .withdrawalCancelTapped:
                state.screen = .account
                return .none
            case .withdrawalProceedTapped:
                guard state.hasAcknowledgedWithdrawal else { return .none }
                state.isWithdrawalAlertPresented = true
                return .none
            case .withdrawalAlertDismissed:
                state.isWithdrawalAlertPresented = false
                return .none
            case .withdrawalConfirmed:
                guard !state.isWithdrawing else { return .none }
                state.isWithdrawalAlertPresented = false
                state.isWithdrawing = true
                return .merge(
                    .send(.delegate(.withdrawalStarted)),
                    .run { send in
                        do {
                            let apple = try await appleSignInClient.signIn()
                            let user = try await authClient.signInWithApple(apple)
                            try await nicknameClient.deleteProfile(user.id)
                            try await authClient.deleteAccount(apple.authorizationCode)
                            await send(.withdrawalResponse(.success(())))
                        } catch { await send(.withdrawalResponse(.failure(error))) }
                    }
                )
            case .withdrawalResponse(.success):
                state.isWithdrawing = false
                state.screen = .complete
                return .none
            case let .withdrawalResponse(.failure(error)):
                state.isWithdrawing = false
                state.errorMessage = error.localizedDescription
                return .none
            case .errorDismissed:
                state.errorMessage = nil
                return .none
            case .returnToLoginTapped:
                return .send(.delegate(.returnToLogin))
            case .delegate:
                return .none
            }
        }
    }
}
