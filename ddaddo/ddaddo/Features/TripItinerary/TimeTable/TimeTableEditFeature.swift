import ComposableArchitecture
import Foundation

struct TimeTableEditRow: Equatable, Identifiable {
    enum Source: Equatable {
        case schedules([TimeTableSchedule.ID])
        case recommendation(TimeTableRecommendation.ID)
    }

    let id: String
    let source: Source
}

struct TimeTableEditFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var isAddSchedulePresented = false
        var placeSearchText = ""
        var placeSearchResults: [PlaceSearchResult] = []
        var isPlaceSearchLoading = false
        var placeSearchErrorMessage: String?
        var editingScheduleID: TimeTableSchedule.ID?
        var placingGroupID: TimeTableGroup.ID?
        var editingDay: TripDay?
        var selectedMinuteOfDay: Int?
        var rowsByDay: [TripDay: [TimeTableEditRow]] = [:]

        var isTimeSelectionPresented: Bool {
            editingScheduleID != nil || placingGroupID != nil
        }

        mutating func dismissTimeSelection() {
            editingScheduleID = nil
            placingGroupID = nil
            editingDay = nil
            selectedMinuteOfDay = nil
        }
    }

    enum Action: Equatable {
        case backButtonTapped
        case saveButtonTapped
        case addScheduleButtonTapped
        case addScheduleDismissed
        case scheduleTapped(TimeTableSchedule.ID)
        case groupAddButtonTapped(TimeTableGroup.ID)
        case timeSelectionChanged(Int)
        case timeSelectionDoneTapped
        case timeSelectionDismissed
        case placeSearchTextChanged(String)
        case placeSearchResponse([PlaceSearchResult])
        case placeSearchFailed(String)
        case placeSearchResultTapped(PlaceSearchResult)
        case recommendationDropped(TimeTableRecommendation.ID, before: TimeTableEditRow.ID?)
        case scheduleRowMoved(TimeTableEditRow.ID, before: TimeTableEditRow.ID?)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.placeClient) var placeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                state.isAddSchedulePresented = false
                state.dismissTimeSelection()
                return .cancel(id: "time-table-place-search")

            case .saveButtonTapped, .placeSearchResultTapped, .scheduleTapped,
                 .groupAddButtonTapped, .timeSelectionDoneTapped,
                 .recommendationDropped, .scheduleRowMoved:
                return .none

            case let .timeSelectionChanged(minuteOfDay):
                guard state.isTimeSelectionPresented, (0..<1440).contains(minuteOfDay)
                else { return .none }
                state.selectedMinuteOfDay = minuteOfDay
                return .none

            case .timeSelectionDismissed:
                state.dismissTimeSelection()
                return .none

            case .addScheduleButtonTapped:
                state.isAddSchedulePresented = true
                state.placeSearchText = ""
                state.placeSearchErrorMessage = nil
                state.isPlaceSearchLoading = true
                return searchPlaces(query: "도쿄 인기 여행지", debounce: false)

            case .addScheduleDismissed:
                state.isAddSchedulePresented = false
                state.placeSearchText = ""
                state.placeSearchResults = []
                state.isPlaceSearchLoading = false
                state.placeSearchErrorMessage = nil
                return .cancel(id: "time-table-place-search")

            case let .placeSearchTextChanged(text):
                state.placeSearchText = text
                state.placeSearchErrorMessage = nil
                state.isPlaceSearchLoading = true

                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return searchPlaces(
                    query: query.isEmpty ? "도쿄 인기 여행지" : query,
                    debounce: !query.isEmpty
                )

            case let .placeSearchResponse(results):
                state.placeSearchResults = results
                state.isPlaceSearchLoading = false
                return .none

            case let .placeSearchFailed(message):
                state.placeSearchResults = []
                state.isPlaceSearchLoading = false
                state.placeSearchErrorMessage = message
                return .none
            }
        }
    }

    private func searchPlaces(query: String, debounce: Bool) -> Effect<Action> {
        .run { send in
            do {
                if debounce {
                    try await clock.sleep(for: .milliseconds(300))
                }
                let results = try await placeClient.autocomplete(query)
                await send(.placeSearchResponse(results))
            } catch is CancellationError {
                return
            } catch {
                await send(.placeSearchFailed(error.localizedDescription))
            }
        }
        .cancellable(id: "time-table-place-search", cancelInFlight: true)
    }
}
