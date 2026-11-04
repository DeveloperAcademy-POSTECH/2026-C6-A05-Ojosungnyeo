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
        var pendingPlaceSelectionTripID: String?
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
                if state.upcomingTrips.trips.first(where: { $0.id == tripID })?.progress == .itinerary {
                    let trip = state.upcomingTrips.trips.first { $0.id == tripID }
                    state.tripItinerary = TripItineraryFeature.State(selectedTab: .dailyItinerary)
                    state.tripItinerary.timeTable.tripStartDate = trip?.startDate
                    state.tripItinerary.timeTable.tripEndDate = trip?.endDate
                    state.isUpcomingTripsPresented = false
                    state.isTripItineraryPresented = true
                    return .none
                }
                return .none
            case let .tripInvitationResponse(.success(snapshot)):
                guard state.pendingPlaceSelectionTripID == snapshot.tripID else {
                    return .none
                }
                state.pendingPlaceSelectionTripID = nil
                let waitingState = WaitingForParticipantsFeature.State(snapshot: snapshot)
                state.placeSelection = waitingState.placeSelection
                state.isPlaceSelectionPresented = true
                return .none
            case .tripInvitationResponse(.failure):
                state.pendingPlaceSelectionTripID = nil
                return .none
            case .placeSelection(.delegate(.returnToUpcomingTrips)):
                state.isPlaceSelectionPresented = false
                state.isUpcomingTripsPresented = true
                state.pendingPlaceSelectionTripID = nil
                return .cancel(id: "place-selection-trip-request")
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
            case .placeGrouping(.confirmButtonTapped):
                guard state.placeGrouping.haveAllRecommendedGroupsConfirmed,
                      let source = state.placeGrouping.sourcePlaceSelection
                else { return .none }

                state.tripItinerary.timeTable.tripTitle = state.placeGrouping.tripTitle
                state.tripItinerary.timeTable.tripStartDate = source.tripStartDate
                state.tripItinerary.timeTable.tripEndDate = source.tripEndDate
                state.tripItinerary.timeTable.recommendationTripID = source.tripID
                state.tripItinerary.timeTable.recommendations = state.placeGrouping.recommendedGroups
                    .filter { state.placeGrouping.confirmedGroupIDs.contains($0.id) }
                    .flatMap { group in
                        group.places.map { place in
                            let ownerIDs = source.memberPlaces.compactMap { member, places in
                                group.memberIDs.contains(member.rawValue) &&
                                places.contains(where: { $0.id == place.id })
                                    ? member.rawValue : nil
                            }.sorted()
                            return TimeTableRecommendation(
                                id: "\(group.id)-\(place.id)",
                                groupID: group.id,
                                placeID: place.id,
                                placeName: place.name,
                                category: place.category,
                                memberIDs: group.memberIDs,
                                placeOwnerMemberIDs: ownerIDs
                            )
                        }
                    }
                return .none

            case .placeGrouping(.delegate(.proceedToItinerary)):
                let waiting = state.placeGrouping.waitingForConfirmation
                guard waiting.haveAllMembersConfirmed,
                      state.tripItinerary.timeTable.recommendationTripID == waiting.tripID
                else { return .none }
                state.tripItinerary.selectedTab = .dailyItinerary
                state.tripItinerary.timeTable.resetScheduledItinerary()
                state.tripItinerary.routeOverview.replaceItinerary(
                    placements: state.tripItinerary.timeTable.placements,
                    coursesByID: state.tripItinerary.timeTable.coursesByID
                )
                state.isPlaceGroupingPresented = false
                state.isTripItineraryPresented = true
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
            case let .upcomingTrips(.delegate(.proceedToAnalysis(placeSelection))):
                state.placeSelection = placeSelection
                state.placeGrouping = PlaceGroupingFeature.State(
                    placeSelection: placeSelection
                )
                state.isUpcomingTripsPresented = false
                state.isPlaceSelectionPresented = false
                state.isPlaceGroupingPresented = false
                state.isPlaceAnalysisLoading = true
                return .none
            case let .upcomingTrips(.delegate(.proceedToGrouping(placeSelection))):
                state.placeSelection = placeSelection
                state.placeGrouping = PlaceGroupingFeature.State(placeSelection: placeSelection)
                state.isUpcomingTripsPresented = false
                state.isPlaceSelectionPresented = false
                state.isPlaceAnalysisLoading = false
                state.isPlaceGroupingPresented = true
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
                return .none
            case .tripSearch(.delegate(.returnToUpcomingTrips)):
                state.isTripSearchPresented = false
                state.isUpcomingTripsPresented = true
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

}
