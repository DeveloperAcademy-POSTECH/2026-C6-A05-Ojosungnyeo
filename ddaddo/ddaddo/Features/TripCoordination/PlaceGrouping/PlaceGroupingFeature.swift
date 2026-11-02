//
//  PlaceGroupingFeature.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

import ComposableArchitecture

struct PlaceGroupingFeature: Reducer {
    enum Tab: Equatable {
        case preferences
        case recommendedGroups
    }

    struct Member: Equatable, Identifiable {
        let id: String
        let name: String
        let preferences: String
        let avatar: ParticipantAvatar
    }

    struct RecommendedGroup: Equatable, Identifiable {
        let id: String
        let title: String
        let participantSummary: String
    }

    @ObservableState
    struct State: Equatable {
        var tripTitle = PlaceGroupingPreviewData.tripTitle
        var tripDates = PlaceGroupingPreviewData.tripDates
        var travelCriteria = PlaceGroupingPreviewData.travelCriteria
        var selectedTab = Tab.preferences
        var members = PlaceGroupingPreviewData.members
        var placeGroups = PlaceGroupingPreviewData.placeGroups
        var recommendedGroups = PlaceGroupingPreviewData.recommendedGroups
        var confirmedGroupID: String?
        var selectedGroupID: String?
        var detail = PlaceGroupingDetailFeature.State()
        var isDetailPresented = false
        var isCriteriaChangeConfirmationPresented = false
        var waitingForConfirmation = WaitingForConfirmationFeature.State()
        var isWaitingForConfirmationPresented = false
    }

    @CasePathable
    enum Action: Equatable {
        case travelCriteriaChangeTapped
        case criteriaChangeCancelTapped
        case criteriaChangeConfirmTapped
        case tabSelected(Tab)
        case memberTapped(String)
        case recommendedGroupTapped(String)
        case detail(PlaceGroupingDetailFeature.Action)
        case confirmButtonTapped
        case waitingForConfirmation(WaitingForConfirmationFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .travelCriteriaChangeTapped:
                state.isCriteriaChangeConfirmationPresented = true
                return .none
            case .criteriaChangeCancelTapped:
                state.isCriteriaChangeConfirmationPresented = false
                return .none
            case .criteriaChangeConfirmTapped:
                state.isCriteriaChangeConfirmationPresented = false
                state.confirmedGroupID = nil
                state.selectedGroupID = nil
                return .none
            case .memberTapped:
                return .none
            case let .recommendedGroupTapped(id):
                state.selectedGroupID = id
                state.detail = PlaceGroupingDetailFeature.State()
                state.detail.groupTitle = id == "shinjuku"
                    ? "신주쿠를 가게따"
                    : "주오를 가게따"
                state.detail.isOwnedGroup = id == "shinjuku"
                state.isDetailPresented = true
                return .none
            case .detail(.delegate(.confirmed)):
                state.confirmedGroupID = state.selectedGroupID
                state.isDetailPresented = false
                return .none
            case .detail(.delegate(.joined)):
                state.confirmedGroupID = state.selectedGroupID
                state.isDetailPresented = false
                return .none
            case .detail(.backButtonTapped):
                state.isDetailPresented = false
                return .none
            case .detail:
                return .none
            case .confirmButtonTapped:
                state.isWaitingForConfirmationPresented = true
                return .none
            case .waitingForConfirmation(.backButtonTapped):
                state.isWaitingForConfirmationPresented = false
                return .none
            case .waitingForConfirmation:
                return .none
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            }
        }

        Scope(state: \.waitingForConfirmation, action: \.waitingForConfirmation) {
            WaitingForConfirmationFeature()
        }

        Scope(state: \.detail, action: \.detail) {
            PlaceGroupingDetailFeature()
        }
    }
}
