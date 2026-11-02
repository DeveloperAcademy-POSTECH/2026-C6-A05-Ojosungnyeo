//
//  HomeFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct HomeFeature: Reducer {
    enum MascotMessage: Int, CaseIterable, Equatable {
        case welcome
        case destination
        case friends

        func text(nickname: String) -> String {
            switch self {
            case .welcome:
                "어서오세따. 저는 따또입니따.\n\(nickname)의 즐거운 지구 여행을 책임집니따."
            case .destination:
                "\(nickname), 어디로 여행을 가볼까따?\n말만 해주세따. 제가 다 도와드리게따."
            case .friends:
                "친구와 함께 가는 여행이라니 즐겁게따.\n\(nickname), 내가 성심성의껏 도와주게따."
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
        var userID = ""
        var nickname = ""
        var mascotMessage = MascotMessage.welcome
        var upcomingTrips = UpcomingTripsFeature.State()
        var isUpcomingTripsPresented = false
        var tripItinerary = TripItineraryFeature.State()
        var isTripItineraryPresented = false
        var placeSelection = PlaceSelectionFeature.State()
        var isPlaceSelectionPresented = false
        var placeGrouping = PlaceGroupingFeature.State()
        var isPlaceAnalysisLoading = false
        var isPlaceGroupingPresented = false
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
        case onAppear
        case nicknameResponse(Result<String, Error>)
        case exploreTripsButtonTapped
        case homeSwipedUp
        case upcomingTrips(UpcomingTripsFeature.Action)
        case tripInvitationResponse(Result<TripInvitationSnapshot, Error>)
        case placeSelection(PlaceSelectionFeature.Action)
        case placeAnalysisFinished
        case placeGrouping(PlaceGroupingFeature.Action)
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
    @Dependency(\.tripClient) var tripClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.userID.isEmpty, state.nickname.isEmpty else { return .none }
                let userID = state.userID
                return .run { send in
                    await send(
                        .nicknameResponse(
                            Result { try await nicknameClient.fetchNickname(userID) }
                        )
                    )
                }
            case let .nicknameResponse(.success(nickname)):
                state.nickname = nickname
                return .none
            case .nicknameResponse(.failure):
                return .none
            case .exploreTripsButtonTapped, .homeSwipedUp:
                state.isUpcomingTripsPresented = true
                state.isMenuPresented = false
                return .none
            case .upcomingTrips(.backButtonTapped):
                state.isUpcomingTripsPresented = false
                return .none
            case let .upcomingTrips(.viewScheduleButtonTapped(tripID)):
                state.isTripItineraryPresented = false
                state.isUpcomingTripsPresented = true
                if tripID == "development-trip-123456" {
                    state.placeSelection = Self.developmentPlaceSelectionState()
                    state.isPlaceSelectionPresented = true
                }
                return .run { send in
                    await send(
                        .tripInvitationResponse(
                            Result { try await tripClient.fetchInvitation(tripID) }
                        )
                    )
                }
            case let .tripInvitationResponse(.success(snapshot)):
                let waitingState = WaitingForParticipantsFeature.State(snapshot: snapshot)
                var placeSelection = waitingState.placeSelection
                if snapshot.tripID == "development-trip-123456" {
                    placeSelection = Self.applyDevelopmentAdminFallback(to: placeSelection)
                }
                state.placeSelection = placeSelection
                state.isPlaceSelectionPresented = true
                return .none
            case .tripInvitationResponse(.failure):
                // 123456 데모 방은 서버 읽기가 일시적으로 실패해도 즉시 열린 화면을 유지한다.
                return .none
            case .placeSelection(.backButtonTapped):
                state.isPlaceSelectionPresented = false
                state.isUpcomingTripsPresented = true
                return .none
            case .placeSelection(.delegate(.proceedToAnalysis)):
                state.placeGrouping = PlaceGroupingFeature.State(
                    placeSelection: state.placeSelection
                )
                state.isPlaceSelectionPresented = false
                state.isPlaceGroupingPresented = false
                state.isPlaceAnalysisLoading = true
                return .none
            case .placeAnalysisFinished:
                state.isPlaceAnalysisLoading = false
                state.isPlaceGroupingPresented = true
                return .none
            case .placeSelection:
                return .none
            case .placeGrouping:
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
                 .tripItinerary(.delegate(.returnToUpcomingTrips)):
                state.isTripItineraryPresented = false
                state.isUpcomingTripsPresented = true
                return .none
            case .tripItinerary:
                return .none
            case .tripSearch(.backButtonTapped):
                state.isTripSearchPresented = false
                return .none
            case .tripSearch(.delegate(.returnHome)):
                state.isTripSearchPresented = false
                state.isUpcomingTripsPresented = true
                return .send(.upcomingTrips(.onAppear))
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

        Scope(state: \.placeSelection, action: \.placeSelection) {
            PlaceSelectionFeature()
        }

        Scope(state: \.placeGrouping, action: \.placeGrouping) {
            PlaceGroupingFeature()
        }

        Scope(state: \.tripSearch, action: \.tripSearch) {
            TripSearchFeature()
        }

        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
    }

    private static func developmentPlaceSelectionState() -> PlaceSelectionFeature.State {
        let startDate = Calendar.current.date(
            from: DateComponents(year: 2026, month: 11, day: 22)
        )!
        let endDate = Calendar.current.date(
            from: DateComponents(year: 2026, month: 11, day: 25)
        )!
        return PlaceSelectionFeature.State(
            tripID: "development-trip-123456",
            tripTitle: "3박 4일 도쿄여행",
            destinationName: "도쿄",
            tripStartDate: startDate,
            tripEndDate: endDate,
            participants: [
                .init(
                    id: 0,
                    member: .header,
                    name: "관리자관리자",
                    hasJoined: true,
                    isCurrentUser: false
                ),
                .init(
                    id: 1,
                    member: .juni,
                    name: "주니",
                    hasJoined: true,
                    isCurrentUser: true
                )
            ],
            memberPlaces: [.header: developmentAdminPlaces],
            remainingSeconds: 60
        )
    }

    private static func applyDevelopmentAdminFallback(
        to state: PlaceSelectionFeature.State
    ) -> PlaceSelectionFeature.State {
        var state = state
        // 고정 초대 코드 123456은 장소 선택 종료 동작을 빠르게 확인하기 위한 데모 방이다.
        state.remainingSeconds = 60
        state.participants = state.participants.map { participant in
            guard participant.member == .header else { return participant }
            return PlaceSelectionFeature.Participant(
                id: participant.id,
                member: participant.member,
                name: participant.name,
                hasJoined: true,
                isCurrentUser: participant.isCurrentUser,
                isConfirmed: participant.isConfirmed
            )
        }
        if !state.participants.contains(where: { $0.member == .header }) {
            state.participants.insert(
                .init(
                    id: 0,
                    member: .header,
                    name: "관리자관리자",
                    hasJoined: true,
                    isCurrentUser: false
                ),
                at: 0
            )
        }
        if state.memberPlaces[.header, default: []].isEmpty {
            state.memberPlaces[.header] = developmentAdminPlaces
        }
        return state
    }

    private static let developmentAdminPlaces: [PinnedPlace] = [
        PinnedPlace(
            id: "development-stussy-tokyo",
            name: "스투시 도쿄점",
            description: "1 Chome-14-5 Jingumae, Shibuya, Tokyo",
            thumbnailName: "DDMockPlaceVillage",
            category: "쇼핑",
            latitude: 35.67118,
            longitude: 139.70564
        ),
        PinnedPlace(
            id: "development-dover-ginza",
            name: "도버 스트리트 마켓 긴자",
            description: "6 Chome-9-5 Ginza, Chuo City, Tokyo",
            thumbnailName: "DDMockPlaceVillage",
            category: "쇼핑",
            latitude: 35.66965,
            longitude: 139.76355
        ),
        PinnedPlace(
            id: "development-tokyo-tower",
            name: "도쿄 타워",
            description: "4 Chome-2-8 Shibakoen, Minato City, Tokyo",
            thumbnailName: "DDMockPlaceVillage",
            category: "관광지",
            latitude: 35.65858,
            longitude: 139.74543
        )
    ]
}
