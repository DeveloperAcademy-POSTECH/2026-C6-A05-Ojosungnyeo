//
//  SettingsFeature.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

import ComposableArchitecture
import FirebaseFirestore
import Foundation
import UserNotifications

struct SettingsFeature: Reducer {
    enum Screen: Equatable { case settings, nickname, account, withdrawal, complete }

    @ObservableState
    struct State: Equatable {
        var userID = ""
        var screen = Screen.settings
        var nickname = ""
        var nicknameDraft = ""
        var isNotificationsEnabled = true
        var isNotificationSettingLoading = false
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
        case notificationSettingLoaded(Bool)
        case backButtonTapped
        case nicknameEditTapped
        case accountManagementTapped
        case notificationSettingChanged(Bool)
        case notificationSettingResponse(Result<Bool, Error>)
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
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.appleSignInClient) var appleSignInClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let userID = state.userID
                var effects: [Effect<Action>] = [
                    .run { send in
                        await send(
                            .notificationSettingLoaded(
                                await notificationClient.isEnabled(userID)
                            )
                        )
                    }
                ]
                if !userID.isEmpty, state.nickname.isEmpty {
                    effects.append(
                        .run { send in
                            await send(
                                .nicknameLoaded(
                                    Result {
                                        try await nicknameClient.fetchNickname(userID)
                                    }
                                )
                            )
                        }
                    )
                }
                return .merge(effects)
            case let .nicknameLoaded(.success(nickname)):
                state.nickname = nickname
                state.nicknameDraft = nickname
                return .none
            case .nicknameLoaded(.failure):
                state.errorMessage = "닉네임을 불러오지 못했어요."
                return .none
            case let .notificationSettingLoaded(isEnabled):
                state.isNotificationsEnabled = isEnabled
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
            case let .notificationSettingChanged(isEnabled):
                guard !state.isNotificationSettingLoading else { return .none }
                state.isNotificationSettingLoading = true
                let userID = state.userID
                return .run { send in
                    await send(
                        .notificationSettingResponse(
                            Result {
                                try await notificationClient.setEnabled(
                                    isEnabled,
                                    userID
                                )
                            }
                        )
                    )
                }
            case let .notificationSettingResponse(.success(isEnabled)):
                state.isNotificationSettingLoading = false
                state.isNotificationsEnabled = isEnabled
                return .none
            case let .notificationSettingResponse(.failure(error)):
                state.isNotificationSettingLoading = false
                state.isNotificationsEnabled = false
                state.errorMessage = error as? NotificationClientError == .authorizationDenied
                    ? "알림 권한이 꺼져 있어요.\n기기 설정에서 알림을 허용해 주세요."
                    : "알림 설정을 변경하지 못했어요.\n잠시 후 다시 시도해 주세요."
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

private enum NotificationClientError: Error, Equatable {
    case authorizationDenied
}

struct NotificationClient: DependencyKey, Sendable {
    var isEnabled: @MainActor @Sendable (String) async -> Bool
    var setEnabled: @MainActor @Sendable (Bool, String) async throws -> Bool

    static let liveValue = Self(
        isEnabled: { userID in
            await NotificationSettingsService.isEnabled(userID: userID)
        },
        setEnabled: { isEnabled, userID in
            try await NotificationSettingsService.setEnabled(
                isEnabled,
                userID: userID
            )
        }
    )

    static let testValue = Self(
        isEnabled: { _ in false },
        setEnabled: { isEnabled, _ in isEnabled }
    )

    static let previewValue = Self(
        isEnabled: { _ in true },
        setEnabled: { isEnabled, _ in isEnabled }
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}

private enum NotificationSettingsService {
    private static let preferenceKeyPrefix = "notificationsEnabled"

    @MainActor
    static func isEnabled(userID: String) async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isAuthorized = settings.authorizationStatus.allowsNotifications
        let savedPreference = UserDefaults.standard.object(
            forKey: preferenceKey(userID: userID)
        ) as? Bool

        return (savedPreference ?? isAuthorized) && isAuthorized
    }

    @MainActor
    static func setEnabled(_ isEnabled: Bool, userID: String) async throws -> Bool {
        if isEnabled {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let isAuthorized: Bool

            switch settings.authorizationStatus {
            case .notDetermined:
                isAuthorized = try await center.requestAuthorization(
                    options: [.alert, .badge, .sound]
                )
            case .authorized, .provisional, .ephemeral:
                isAuthorized = true
            case .denied:
                isAuthorized = false
            @unknown default:
                isAuthorized = false
            }

            guard isAuthorized else {
                saveLocalPreference(false, userID: userID)
                try await saveRemotePreference(false, userID: userID)
                throw NotificationClientError.authorizationDenied
            }

            saveLocalPreference(true, userID: userID)
            try await saveRemotePreference(true, userID: userID)
            return true
        }

        saveLocalPreference(false, userID: userID)
        try await saveRemotePreference(false, userID: userID)

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        try? await center.setBadgeCount(0)
        return false
    }

    private static func preferenceKey(userID: String) -> String {
        userID.isEmpty
            ? preferenceKeyPrefix
            : "\(preferenceKeyPrefix).\(userID)"
    }

    private static func saveLocalPreference(_ isEnabled: Bool, userID: String) {
        UserDefaults.standard.set(
            isEnabled,
            forKey: preferenceKey(userID: userID)
        )
    }

    private static func saveRemotePreference(_ isEnabled: Bool, userID: String) async throws {
        guard !userID.isEmpty, FirebaseService.isConfigured else { return }

        try await Firestore.firestore()
            .collection("users")
            .document(userID)
            .setData(
                [
                    "notificationsEnabled": isEnabled,
                    "notificationsUpdatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
    }
}

private extension UNAuthorizationStatus {
    var allowsNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}
