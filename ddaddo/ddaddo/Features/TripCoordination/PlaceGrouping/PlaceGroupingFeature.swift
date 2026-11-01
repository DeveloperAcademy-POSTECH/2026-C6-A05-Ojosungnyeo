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
    }

    enum Action: Equatable {
        case travelCriteriaChangeTapped
        case tabSelected(Tab)
        case memberTapped(String)
        case recommendedGroupTapped(String)
        case confirmButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .travelCriteriaChangeTapped,
                 .memberTapped,
                 .recommendedGroupTapped,
                 .confirmButtonTapped:
                return .none
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            }
        }
    }
}
