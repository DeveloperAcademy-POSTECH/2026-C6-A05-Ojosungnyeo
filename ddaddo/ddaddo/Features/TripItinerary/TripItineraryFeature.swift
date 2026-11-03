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
                if tab == .routeOverview {
                    state.synchronizeRouteWithTimeTable()
                }
                return .none

            case .routeOverview(.editingDoneButtonTapped):
                state.applyRouteEditsToTimeTable()
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

private extension TripItineraryFeature.State {
    mutating func synchronizeRouteWithTimeTable() {
        routeOverview.replaceItinerary(
            placements: timeTable.placements,
            coursesByID: timeTable.coursesByID
        )
    }

    mutating func applyRouteEditsToTimeTable() {
        guard let draftStopsByDay = routeOverview.draftStopsByDay else { return }

        let retainedScheduleIDs = Set(
            draftStopsByDay.values
                .flatMap { $0 }
                .compactMap(\.scheduleID)
        )
        timeTable.placements.removeAll { !retainedScheduleIDs.contains($0.id) }

        for day in TripDay.allCases {
            let orderedStops = draftStopsByDay[day, default: []].sorted {
                $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order
            }
            let existingMinutes = timeTable.placements
                .filter { $0.day == day }
                .map(\.timing.startMinuteOfDay)
                .sorted()

            for (index, stop) in orderedStops.enumerated() {
                guard let scheduleID = stop.scheduleID,
                      let placementIndex = timeTable.placements.firstIndex(where: { $0.id == scheduleID })
                else { continue }
                let fallbackMinute = (existingMinutes.last ?? 9 * 60) + max(0, index - existingMinutes.count + 1) * 60
                timeTable.placements[placementIndex].timing.startMinuteOfDay =
                    existingMinutes.indices.contains(index) ? existingMinutes[index] : fallbackMinute
            }
        }
    }
}
