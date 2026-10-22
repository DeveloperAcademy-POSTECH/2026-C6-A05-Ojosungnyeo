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
        var selectedTab: Tab = .routeOverview
        var routeOverview = RouteOverviewFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case routeOverview(RouteOverviewFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case .routeOverview:
                return .none
            }
        }

        Scope(state: \.routeOverview, action: \.routeOverview) {
            RouteOverviewFeature()
        }
    }
}
