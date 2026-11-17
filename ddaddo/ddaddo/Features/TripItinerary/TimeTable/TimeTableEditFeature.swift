import ComposableArchitecture
import Foundation

struct TimeTableEditRow: Equatable, Identifiable {
    enum Source: Hashable {
        case schedule(TimeTableSchedule.ID)
        case recommendationGroup(String)
    }

    let id: String
    var sources: [Source]
    var branchGroupID: String?
}

struct TimeTableEditFeature: Reducer {
    enum PlaceDeletionTarget: Equatable {
        case course(scheduleID: TimeTableSchedule.ID, courseID: TimeTableCourse.ID, placeID: UUID)
        case recommendation(groupID: String, recommendationID: String)
    }

    enum Delegate: Equatable {
        case addPlaceRequested
    }

    @ObservableState
    struct State: Equatable {
        enum PendingDeletion: Equatable {
            case row(day: TripDay, rowID: TimeTableEditRow.ID, source: TimeTableEditRow.Source)
            case place(PlaceDeletionTarget)

            var isPlace: Bool {
                if case .place = self { return true }
                return false
            }
        }

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
        var draftPlacements: [TimeTableSchedule] = []
        var originalCoursesByID: [TimeTableCourse.ID: TimeTableCourse]?
        var originalRecommendations: [TimeTableRecommendation]?
        var coursePlaceIDsByID: [TimeTableCourse.ID: [UUID]] = [:]
        var isSaving = false
        var isSaveUnavailableAlertPresented = false
        var saveErrorMessage = "일정을 저장하지 못했어요.\n잠시 후 다시 시도해 주세요."
        var pendingDeletion: PendingDeletion?

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
        case recommendationDropped(String, before: TimeTableEditRow.ID?)
        case scheduleRowMoved(TimeTableEditRow.ID, source: TimeTableEditRow.Source, before: TimeTableEditRow.ID?)
        case rowMovedToDay(TimeTableEditRow.ID, source: TimeTableEditRow.Source, day: TripDay)
        case rowMerged(TimeTableEditRow.ID, source: TimeTableEditRow.Source, into: TimeTableEditRow.ID)
        case recommendationMerged(String, into: TimeTableEditRow.ID)
        case coursePlaceMoved(TimeTableCourse.ID, sourceIndex: Int, beforeIndex: Int)
        case recommendationPlaceMoved(String, sourceIndex: Int, beforeIndex: Int)
        case placeDeletionRequested(PlaceDeletionTarget)
        case deletionRequested(TripDay, rowID: TimeTableEditRow.ID, source: TimeTableEditRow.Source)
        case deletionCancelled
        case deletionConfirmed
        case saveUnavailableAlertDismissed
        case delegate(Delegate)
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
                 .recommendationDropped, .scheduleRowMoved, .rowMovedToDay, .rowMerged, .recommendationMerged,
                 .coursePlaceMoved,
                 .recommendationPlaceMoved,
                 .delegate:
                return .none

            case let .deletionRequested(day, rowID, source):
                state.pendingDeletion = .row(day: day, rowID: rowID, source: source)
                return .none

            case let .placeDeletionRequested(target):
                state.pendingDeletion = .place(target)
                return .none

            case .deletionCancelled:
                state.pendingDeletion = nil
                return .none

            case .deletionConfirmed:
                guard case let .row(day, rowID, source)? = state.pendingDeletion,
                      var rows = state.rowsByDay[day],
                      let rowIndex = rows.firstIndex(where: { $0.id == rowID }),
                      let sourceIndex = rows[rowIndex].sources.firstIndex(of: source)
                else {
                    state.pendingDeletion = nil
                    return .none
                }

                rows[rowIndex].sources.remove(at: sourceIndex)
                if case let .schedule(scheduleID) = source {
                    state.draftPlacements.removeAll { $0.id == scheduleID }
                }
                if rows[rowIndex].sources.isEmpty {
                    rows.remove(at: rowIndex)
                } else if rows[rowIndex].sources.count == 1 {
                    rows[rowIndex].branchGroupID = nil
                }
                state.rowsByDay[day] = rows
                state.pendingDeletion = nil
                return .none

            case .saveUnavailableAlertDismissed:
                state.isSaveUnavailableAlertPresented = false
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
                return .send(.delegate(.addPlaceRequested))

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
