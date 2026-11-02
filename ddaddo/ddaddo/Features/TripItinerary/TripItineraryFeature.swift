//
//  TripItineraryFeature.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture

struct TripItineraryFeature: Reducer {
    enum Delegate: Equatable {
        case returnToUpcomingTrips
    }

    enum Tab: Hashable {
        case dailyItinerary
        case routeOverview
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .routeOverview
        var timeTable = TimeTableFeature.State()
        var routeOverview = RouteOverviewFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case timeTable(TimeTableFeature.Action)
        case routeOverview(RouteOverviewFeature.Action)
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case .routeOverview(.backButtonTapped):
                return .send(.delegate(.returnToUpcomingTrips))

            case .timeTable, .routeOverview, .delegate:
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
