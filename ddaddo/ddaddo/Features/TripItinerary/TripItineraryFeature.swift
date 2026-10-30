//
//  TripItineraryFeature.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture

struct TripItineraryFeature: Reducer {
    enum Tab: Hashable {
        case dailyItinerary
        case routeOverview
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .dailyItinerary
        var timeTable = TimeTableFeature.State()
        var routeOverview = RouteOverviewFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case timeTable(TimeTableFeature.Action)
        case routeOverview(RouteOverviewFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case .routeOverview(.backButtonTapped):
                state.selectedTab = .dailyItinerary
                return .none

            case .timeTable, .routeOverview:
                return .none
            }
        }

        Scope(state: \.timeTable, action: \.timeTable) {
            TimeTableFeature()
        }

        Scope(state: \.routeOverview, action: \.routeOverview) {
            RouteOverviewFeature()
        }
    }
}
