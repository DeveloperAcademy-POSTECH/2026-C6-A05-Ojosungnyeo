//
//  HomeFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct HomeFeature: Reducer {
    enum MascotMessage: Int, CaseIterable, Equatable {
        case welcome
        case destination
        case friends

        var text: String {
            switch self {
            case .welcome:
                "어서오세따. 저는 따또입니따.\n당신의 즐거운 지구 여행을 책임집니따."
            case .destination:
                "어디로 여행을 가볼까따?\n말만 해주세따. 제가 다 도와드리게따."
            case .friends:
                "친구와 함께 가는 여행이라니 즐겁게따.\n내가 성심성의껏 도와주게따."
            }
        }

        var next: Self {
            let messages = Self.allCases
            let nextIndex = (rawValue + 1) % messages.count
            return messages[nextIndex]
        }
    }

    @ObservableState
    struct State: Equatable {
        var mascotMessage = MascotMessage.welcome
        var upcomingTrips = UpcomingTripsPreviewData.state
        var isUpcomingTripsPresented = false
        var tripItinerary = TripItineraryFeature.State()
        var isTripItineraryPresented = false
        var tripSearch = TripSearchFeature.State()
        var isTripSearchPresented = false
        var isMenuPresented = false
        var settings = SettingsFeature.State()
        var isSettingsPresented = false
        var isWithdrawalConfirmationPresented = false
        var isWithdrawing = false
        var withdrawalErrorMessage: String?
    }

    @CasePathable
    enum Action {
        case exploreTripsButtonTapped
        case homeSwipedUp
        case upcomingTrips(UpcomingTripsFeature.Action)
        case tripItinerary(TripItineraryFeature.Action)
        case tripSearch(TripSearchFeature.Action)
        case mascotTapped
        case menuButtonTapped
        case settings(SettingsFeature.Action)
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
    @Dependency(\.nicknameClient) var nicknameClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .exploreTripsButtonTapped, .homeSwipedUp:
                state.isUpcomingTripsPresented = true
                state.isMenuPresented = false
                return .none
            case .upcomingTrips(.backButtonTapped):
                state.isUpcomingTripsPresented = false
                return .none
            case .upcomingTrips(.viewScheduleButtonTapped):
                state.tripItinerary = TripItineraryFeature.State()
                state.isTripItineraryPresented = true
                return .none
            case .upcomingTrips(.createTripButtonTapped):
                state.tripSearch = TripSearchFeature.State()
                state.isTripSearchPresented = true
                return .none
            case .upcomingTrips(.delegate(.returnHome)):
                state.isUpcomingTripsPresented = false
                return .none
            case .upcomingTrips:
                return .none
            case .tripItinerary(.timeTable(.backButtonTapped)),
                 .tripItinerary(.routeOverview(.backButtonTapped)):
                state.isTripItineraryPresented = false
                return .none
            case .tripItinerary:
                return .none
            case .tripSearch(.backButtonTapped):
                state.isTripSearchPresented = false
                return .none
            case .tripSearch(.delegate(.returnHome)):
                state.isTripSearchPresented = false
                return .none
            case .tripSearch:
                return .none
            case .mascotTapped:
                state.mascotMessage = state.mascotMessage.next
                return .none
            case .menuButtonTapped:
                state.isSettingsPresented = true
                return .none
            case .settings(.delegate(.dismiss)):
                state.isSettingsPresented = false
                return .none
            case .settings:
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
                        let user = try await authClient.signInWithApple(appleResult)
                        try await nicknameClient.deleteProfile(user.id)
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

                if let nicknameError = error as? NicknameClientError {
                    switch nicknameError {
                    case .firebaseNotConfigured:
                        state.withdrawalErrorMessage = "Firebase 설정 파일을 확인해 주세요."
                    case .networkUnavailable:
                        state.withdrawalErrorMessage = "네트워크 연결을 확인해 주세요."
                    case let .saveFailed(code, message):
                        state.withdrawalErrorMessage = "Firestore 오류 \(code): \(message)"
                    case .duplicateNickname:
                        state.withdrawalErrorMessage = "탈퇴 데이터를 정리하지 못했어요."
                    }
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

        Scope(state: \.upcomingTrips, action: \.upcomingTrips) {
            UpcomingTripsFeature()
        }

        Scope(state: \.tripItinerary, action: \.tripItinerary) {
            TripItineraryFeature()
        }

        Scope(state: \.tripSearch, action: \.tripSearch) {
            TripSearchFeature()
        }

        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
    }
}
