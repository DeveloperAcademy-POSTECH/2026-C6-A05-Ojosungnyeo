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
        var routeEditor = RouteEditorFeature.State()
        var isRouteEditorPresented = false
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case timeTable(TimeTableFeature.Action)
        case routeOverview(RouteOverviewFeature.Action)
        case routeEditor(RouteEditorFeature.Action)
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

            case .routeOverview(.backButtonTapped):
                return .send(.delegate(.returnToUpcomingTrips))

            case .routeOverview(.onAppear):
                state.synchronizeRouteWithTimeTable()
                return .send(.timeTable(.onAppear))

            case let .routeOverview(.daySelected(day)):
                state.timeTable.selectedDay = day
                return .none

            case let .timeTable(.daySelected(day)):
                state.routeOverview.selectedDay = day
                return .none

            case .timeTable(.delegate(.addPlaceRequested)):
                state.routeEditor = RouteEditorFeature.State(
                    availableDays: state.timeTable.availableDays
                )
                state.isRouteEditorPresented = true
                return .none

            case .timeTable(.delegate(.itineraryUpdated)):
                state.synchronizeRouteWithTimeTable()
                return .none

            case .routeEditor(.delegate(.dismissed)):
                state.isRouteEditorPresented = false
                return .none

            case let .routeEditor(.delegate(.placeAdded(place, day))):
                state.addPlace(place, to: day)
                state.isRouteEditorPresented = false
                return .none

            case .timeTable, .routeOverview, .routeEditor, .delegate:
                return .none
            }
        }

        Scope(state: \.timeTable, action: \.timeTable) {
            TimeTableFeature()
        }

        Scope(state: \.routeOverview, action: \.routeOverview) {
            RouteOverviewFeature()
        }

        Scope(state: \.routeEditor, action: \.routeEditor) {
            RouteEditorFeature()
        }
    }
}

private extension TripItineraryFeature.State {
    mutating func synchronizeRouteWithTimeTable() {
        let headerTitle = timeTable.routeHeaderTitle
        let availableDays = timeTable.availableDays
        let tripMembers = timeTable.tripMembers
        let currentMember = timeTable.currentTripMember ?? tripMembers.first ?? .tae
        let selectedDay = timeTable.selectedDay
        let placements = timeTable.placements
        let coursesByID = timeTable.coursesByID

        routeOverview.tripHeaderTitle = headerTitle
        routeOverview.availableDays = availableDays
        routeOverview.memberOrder = tripMembers
        routeOverview.currentMember = currentMember
        routeOverview.selectedMembers.formIntersection(tripMembers)
        routeOverview.selectedMemberOrder.removeAll { !tripMembers.contains($0) }
        routeOverview.selectedDay = availableDays.contains(selectedDay)
            ? selectedDay
            : availableDays.first ?? .day1
        routeOverview.replaceItinerary(
            placements: placements,
            coursesByID: coursesByID
        )
    }

    mutating func addPlace(_ place: PlaceDetails, to day: TripDay) {
        let nextCourseID = (timeTable.coursesByID.keys.max() ?? -1) + 1
        timeTable.coursesByID[nextCourseID] = TimeTableCourse(
            id: nextCourseID,
            title: place.name,
            placeCount: 1,
            placeNames: [place.name],
            categories: [place.category],
            members: timeTable.tripMembers,
            durationMinutes: 60,
            places: [
                ItineraryPlace(
                    name: place.name,
                    category: place.category,
                    latitude: place.latitude,
                    longitude: place.longitude
                )
            ]
        )

        let existingPlacementIDs = timeTable.edit.draftPlacements.map(\.id)
            + timeTable.placements.map(\.id)
        let nextScheduleID = (existingPlacementIDs.max() ?? -1) + 1
        let dayPlacements = timeTable.edit.draftPlacements.filter { $0.day == day }
        let startMinute = min(
            dayPlacements.compactMap { placement in
                timeTable.coursesByID[placement.courseID].map {
                    placement.timing.startMinuteOfDay + $0.durationMinutes
                }
            }.max() ?? 9 * 60,
            23 * 60
        )
        let placement = TimeTableSchedule(
            id: nextScheduleID,
            courseID: nextCourseID,
            day: day,
            timing: .init(startMinuteOfDay: startMinute),
            branchGroupID: nil
        )
        timeTable.edit.draftPlacements.append(placement)
        timeTable.edit.rowsByDay[day, default: []].append(
            TimeTableEditRow(
                id: "\(day.rawValue)-schedule-\(nextScheduleID)",
                sources: [.schedule(nextScheduleID)]
            )
        )
        timeTable.selectedDay = day
    }
}
