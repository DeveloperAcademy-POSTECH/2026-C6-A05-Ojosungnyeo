//
//  TimeTableFeature.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture
import Foundation

struct TimeTableFeature: Reducer {
    enum Delegate: Equatable {
        case addPlaceRequested
    }

    @ObservableState
    struct State: Equatable {
        var selectedDay = TripDay.day1
        var tripMembers = TripMember.allCases
        var tripStartDate: Date? = nil
        var tripEndDate: Date? = nil
        var tripTitle: String?
        var destinationName: String?
        var recommendationTripID: String?
        var recommendations: [TimeTableRecommendation] = []
        var dayOfMonthByDay: [TripDay: Int] = [
            .day1: 22, .day2: 23, .day3: 24, .day4: 25
        ]
        var coursesByID: [TimeTableCourse.ID: TimeTableCourse] = [:]
        var expandedCourseIDs: Set<TimeTableCourse.ID> = []
        var groups: [TimeTableGroup] = []
        var placements: [TimeTableSchedule] = []
        var hasLoadedItinerary = false
        var isEditing = false
        var edit = TimeTableEditFeature.State()
        #if DEBUG
        var isLocalPreview = false
        var savedPreviewRowsByDay: [TripDay: [TimeTableEditRow]]?
        var savedPreviewPlacements: [TimeTableSchedule]?
        #endif

        var availableDays: [TripDay] {
            guard let tripStartDate, let tripEndDate else {
                let fallback = TripDay.allCases.filter { dayOfMonthByDay[$0] != nil }
                return fallback.isEmpty ? [.day1] : fallback
            }

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let startDay = calendar.startOfDay(for: tripStartDate)
            let endDay = calendar.startOfDay(for: tripEndDate)
            guard let nights = calendar.dateComponents([.day], from: startDay, to: endDay).day,
                  nights >= 0 else { return [.day1] }
            return Array(TripDay.allCases.prefix(min(nights + 1, TripDay.allCases.count)))
        }

        var headerTitle: String {
            guard let destinationName = destinationName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !destinationName.isEmpty
            else { return "여행 일정을 살펴보게따" }
            return "\(destinationName) 여행을 살펴보게따"
        }

        var tripDateText: String? {
            if let startDate = tripStartDate, let endDate = tripEndDate {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = .current
                let startDay = calendar.startOfDay(for: startDate)
                let endDay = calendar.startOfDay(for: endDate)
                guard let nights = calendar.dateComponents([.day], from: startDay, to: endDay).day,
                      nights >= 0 else { return nil }

                let startMonth = calendar.component(.month, from: startDay)
                let startDayOfMonth = calendar.component(.day, from: startDay)
                let endMonth = calendar.component(.month, from: endDay)
                let endDayOfMonth = calendar.component(.day, from: endDay)
                let sameMonth = calendar.component(.year, from: startDay)
                    == calendar.component(.year, from: endDay) && startMonth == endMonth
                let endText = sameMonth ? "\(endDayOfMonth)일" : "\(endMonth)월 \(endDayOfMonth)일"
                return "\(startMonth)월 \(startDayOfMonth)일 ~ \(endText) · \(nights)박 \(nights + 1)일"
            }

            guard tripStartDate == nil, tripEndDate == nil else { return nil }
            let days = TripDay.allCases.compactMap { dayOfMonthByDay[$0] }
            guard let first = days.first, let last = days.last else { return nil }
            for index in 1..<days.count where days[index] != days[index - 1] + 1 {
                return nil
            }
            let nights = days.count - 1
            return "\(first)일 ~ \(last)일 · \(nights)박 \(nights + 1)일"
        }

        var unplacedGroups: [TimeTableGroup] {
            let placedCourseIDs = Set((isEditing ? edit.draftPlacements : placements).map(\.courseID))
            return groups.filter { group in
                !group.courseIDs.isEmpty &&
                group.courseIDs.allSatisfy { !placedCourseIDs.contains($0) }
            }
        }

        var timeSelectionCourseIDs: [TimeTableCourse.ID]? {
            guard let day = edit.editingDay, day == selectedDay else { return nil }

            if let scheduleID = edit.editingScheduleID {
                return edit.draftPlacements.first(where: { $0.id == scheduleID && $0.day == day })
                    .map { [$0.courseID] }
            }
            if let groupID = edit.placingGroupID {
                return unplacedGroups.first(where: { $0.id == groupID })?.courseIDs
            }
            return nil
        }

        var hasTimeSelectionConflict: Bool {
            guard let day = edit.editingDay,
                  let minute = edit.selectedMinuteOfDay,
                  let courseIDs = timeSelectionCourseIDs
            else { return false }

            return TimeTableSchedule.hasTimeConflict(
                courseIDs: courseIDs,
                startingAt: minute,
                on: day,
                excluding: edit.editingScheduleID,
                placements: edit.draftPlacements,
                coursesByID: coursesByID
            )
        }

        var canConfirmTimeSelection: Bool {
            guard edit.editingDay == selectedDay,
                  let minute = edit.selectedMinuteOfDay,
                  (0..<1440).contains(minute),
                  let courseIDs = timeSelectionCourseIDs,
                  !courseIDs.isEmpty,
                  Set(courseIDs).count == courseIDs.count,
                  courseIDs.allSatisfy({ id in
                      guard let course = coursesByID[id] else { return false }
                      return course.durationMinutes > 0 && !course.members.isEmpty
                  })
            else { return false }

            return !hasTimeSelectionConflict
        }

        mutating func resetScheduledItinerary() {
            selectedDay = .day1
            coursesByID = [:]
            groups = []
            placements = []
            hasLoadedItinerary = false
            isEditing = false
            edit = TimeTableEditFeature.State()
            #if DEBUG
            savedPreviewRowsByDay = nil
            savedPreviewPlacements = nil
            #endif
        }

        mutating func materializeRecommendationRows() {
            var nextCourseID = (coursesByID.keys.max() ?? -1) + 1
            var nextScheduleID = (edit.draftPlacements.map(\.id).max() ?? -1) + 1
            var nextBranchID = (edit.draftPlacements.compactMap(\.branchGroupID).max() ?? -1) + 1

            for day in TripDay.allCases {
                let rows = edit.rowsByDay[day, default: []]
                for (rowIndex, row) in rows.enumerated() {
                    let recommendationSources = row.sources.compactMap { source -> String? in
                        guard case let .recommendationGroup(groupID) = source else { return nil }
                        return groupID
                    }
                    guard !recommendationSources.isEmpty else { continue }
                    let branchID = row.sources.count > 1 ? nextBranchID : nil
                    if branchID != nil { nextBranchID += 1 }
                    var materializedScheduleIDs: [TimeTableSchedule.ID] = []

                    for groupID in recommendationSources {
                        let places = recommendations.filter { $0.groupID == groupID }
                        guard let first = places.first else { continue }
                        let categories = places.categoryValues
                        let memberIDs = places.flatMap(\.memberIDs).reduce(into: [String]()) {
                            guard !$0.contains($1) else { return }
                            $0.append($1)
                        }
                        let course = TimeTableCourse(
                            id: nextCourseID,
                            title: places.count > 1
                                ? "\(first.placeName) 외 \(places.count - 1)곳"
                                : first.placeName,
                            placeCount: places.count,
                            placeNames: places.map(\.placeName),
                            categories: categories,
                            members: memberIDs.compactMap(TripMember.init(rawValue:)),
                            durationMinutes: max(60, places.count * 60),
                            places: places.map {
                                ItineraryPlace(
                                    name: $0.placeName,
                                    category: $0.category,
                                    latitude: $0.latitude,
                                    longitude: $0.longitude
                                )
                            }
                        )
                        coursesByID[nextCourseID] = course
                        edit.draftPlacements.append(
                            TimeTableSchedule(
                                id: nextScheduleID,
                                courseID: nextCourseID,
                                day: day,
                                timing: .init(startMinuteOfDay: 9 * 60 + rowIndex * 90),
                                branchGroupID: branchID
                            )
                        )
                        materializedScheduleIDs.append(nextScheduleID)
                        nextCourseID += 1
                        nextScheduleID += 1
                    }
                    var scheduleIDs = materializedScheduleIDs
                    edit.rowsByDay[day]?[rowIndex].sources = row.sources.map { source in
                        guard case .recommendationGroup = source, !scheduleIDs.isEmpty else {
                            return source
                        }
                        return .schedule(scheduleIDs.removeFirst())
                    }
                }
            }
        }

    }

    @CasePathable
    enum Action: Equatable {
        case backButtonTapped
        case editButtonTapped
        case daySelected(TripDay)
        case groupAddButtonTapped(TimeTableGroup.ID)
        case scheduleTapped(TimeTableSchedule.ID)
        case courseDisclosureTapped(TimeTableCourse.ID)
        case validateSelectedDay
        case onAppear
        case itineraryLoaded(TripItinerarySnapshot?)
        case itineraryLoadFailed
        case itinerarySaveSucceeded
        case itinerarySaveFailed(String)
        case edit(TimeTableEditFeature.Action)
        case delegate(Delegate)
    }

    @Dependency(\.tripClient) var tripClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped, .groupAddButtonTapped, .scheduleTapped, .delegate:
                return .none

            case let .courseDisclosureTapped(courseID):
                if state.expandedCourseIDs.contains(courseID) {
                    state.expandedCourseIDs.remove(courseID)
                } else {
                    state.expandedCourseIDs.insert(courseID)
                }
                return .none

            case .onAppear:
                guard !state.hasLoadedItinerary,
                      let tripID = state.recommendationTripID,
                      !tripID.isEmpty else { return .none }
                state.hasLoadedItinerary = true
                return .run { send in
                    do {
                        await send(.itineraryLoaded(try await tripClient.fetchItinerary(tripID)))
                    } catch {
                        await send(.itineraryLoadFailed)
                    }
                }

            case let .itineraryLoaded(snapshot):
                guard let snapshot else { return .none }
                state.coursesByID = Dictionary(uniqueKeysWithValues: snapshot.courses.map { course in
                    let value = TimeTableCourse(
                        id: course.id,
                        title: course.title,
                        placeCount: course.placeNames.count,
                        placeNames: course.placeNames,
                        categories: course.categories,
                        members: course.memberIDs.compactMap(TripMember.init(rawValue:)),
                        durationMinutes: course.durationMinutes,
                        places: course.places
                    )
                    return (value.id, value)
                })
                state.placements = snapshot.schedules.compactMap { schedule in
                    guard let day = TripDay(rawValue: schedule.day) else { return nil }
                    return TimeTableSchedule(
                        id: schedule.id,
                        courseID: schedule.courseID,
                        day: day,
                        timing: .init(startMinuteOfDay: schedule.startMinuteOfDay),
                        branchGroupID: schedule.branchGroupID
                    )
                }
                return .none

            case .itineraryLoadFailed:
                state.hasLoadedItinerary = false
                return .none

            case .itinerarySaveSucceeded:
                state.placements = state.edit.draftPlacements
                state.edit.isSaving = false
                state.isEditing = false
                state.edit = TimeTableEditFeature.State()
                return .none

            case let .itinerarySaveFailed(message):
                state.edit.isSaving = false
                state.edit.saveErrorMessage = message
                state.edit.isSaveUnavailableAlertPresented = true
                return .none

            case .validateSelectedDay:
                if !state.availableDays.contains(state.selectedDay) {
                    state.selectedDay = .day1
                }
                return .none

            case .edit(.delegate(.addPlaceRequested)):
                return .send(.delegate(.addPlaceRequested))

            case .editButtonTapped:
                state.edit = TimeTableEditFeature.State()
                #if DEBUG
                if state.isLocalPreview, state.recommendationTripID == nil,
                   let saved = state.savedPreviewRowsByDay {
                    state.edit.rowsByDay = saved
                    state.edit.draftPlacements = state.savedPreviewPlacements ?? state.placements
                } else {
                    state.edit.draftPlacements = state.placements
                }
                #else
                state.edit.draftPlacements = state.placements
                #endif
                if state.edit.rowsByDay.isEmpty {
                    for day in TripDay.allCases {
                        state.edit.rowsByDay[day] = Self.initialRows(on: day, placements: state.edit.draftPlacements)
                    }
                }
                state.isEditing = true
                return .none

            case let .edit(.recommendationDropped(id, before: targetID)):
                guard state.recommendations.contains(where: { $0.groupID == id }),
                      !state.edit.rowsByDay.values.flatMap({ $0 }).contains(where: {
                          $0.sources.contains(.recommendationGroup(id))
                      }) else { return .none }
                var rows = state.edit.rowsByDay[state.selectedDay, default: []]
                let row = TimeTableEditRow(id: "recommendation-\(id)", sources: [.recommendationGroup(id)])
                let index = targetID.flatMap { targetID in
                    rows.firstIndex(where: { $0.id == targetID })
                } ?? rows.endIndex
                rows.insert(row, at: index)
                state.edit.rowsByDay[state.selectedDay] = rows
                return .none

            case let .edit(.rowMerged(sourceID, source: source, into: targetID)):
                var rows = state.edit.rowsByDay[state.selectedDay, default: []]
                guard sourceID != targetID,
                      let sourceIndex = rows.firstIndex(where: { $0.id == sourceID }),
                      let sourcePosition = rows[sourceIndex].sources.firstIndex(of: source),
                      let targetIndex = rows.firstIndex(where: { $0.id == targetID }),
                      let sourceMembers = Self.memberIDs(for: source, state: state),
                      let targetMembers = Self.memberIDs(for: rows[targetIndex], state: state),
                      !sourceMembers.isEmpty,
                      sourceMembers.isDisjoint(with: targetMembers)
                else { return .none }

                rows[sourceIndex].sources.remove(at: sourcePosition)
                if rows[sourceIndex].sources.isEmpty {
                    rows.remove(at: sourceIndex)
                } else if rows[sourceIndex].sources.count == 1 {
                    rows[sourceIndex].branchGroupID = nil
                }

                guard let destination = rows.firstIndex(where: { $0.id == targetID }) else { return .none }
                rows[destination].sources.append(source)
                rows[destination].branchGroupID = rows[destination].branchGroupID ?? "local-\(UUID().uuidString)"
                state.edit.rowsByDay[state.selectedDay] = rows
                return .none

            case let .edit(.recommendationMerged(groupID, into: targetID)):
                guard let recommendation = state.recommendations.first(where: { $0.groupID == groupID }),
                      !state.edit.rowsByDay.values.flatMap({ $0 }).contains(where: {
                          $0.sources.contains(.recommendationGroup(groupID))
                      }) else { return .none }
                var rows = state.edit.rowsByDay[state.selectedDay, default: []]
                guard let index = rows.firstIndex(where: { $0.id == targetID }),
                      let targetMembers = Self.memberIDs(for: rows[index], state: state),
                      !recommendation.memberIDs.isEmpty,
                      targetMembers.isDisjoint(with: Set(recommendation.memberIDs))
                else { return .none }
                rows[index].sources.append(.recommendationGroup(groupID))
                rows[index].branchGroupID = rows[index].branchGroupID ?? "local-\(UUID().uuidString)"
                state.edit.rowsByDay[state.selectedDay] = rows
                return .none

            case let .edit(.scheduleRowMoved(id, source: source, before: targetID)):
                var rows = state.edit.rowsByDay[state.selectedDay, default: []]
                guard let sourceIndex = rows.firstIndex(where: { $0.id == id }),
                      let sourcePosition = rows[sourceIndex].sources.firstIndex(of: source)
                else { return .none }

                let row: TimeTableEditRow
                if rows[sourceIndex].sources.count == 1 {
                    guard targetID != id else { return .none }
                    row = rows.remove(at: sourceIndex)
                } else {
                    rows[sourceIndex].sources.remove(at: sourcePosition)
                    if rows[sourceIndex].sources.count == 1 {
                        rows[sourceIndex].branchGroupID = nil
                    }
                    row = TimeTableEditRow(
                        id: Self.rowID(for: source, on: state.selectedDay),
                        sources: [source]
                    )
                }

                let targetIndex = targetID.flatMap { targetID in
                    rows.firstIndex(where: { $0.id == targetID })
                } ?? rows.endIndex
                rows.insert(row, at: targetIndex)
                state.edit.rowsByDay[state.selectedDay] = rows
                return .none

            case .edit(.backButtonTapped):
                state.isEditing = false
                state.edit = TimeTableEditFeature.State()
                return .none

            case .edit(.saveButtonTapped):
                #if DEBUG
                if state.isLocalPreview, state.recommendationTripID == nil {
                    state.savedPreviewRowsByDay = state.edit.rowsByDay
                    state.savedPreviewPlacements = state.edit.draftPlacements
                    state.isEditing = false
                    state.edit = TimeTableEditFeature.State()
                    return .none
                }
                #endif
                guard !state.edit.isSaving,
                      let tripID = state.recommendationTripID,
                      !tripID.isEmpty else {
                    state.edit.saveErrorMessage = "저장할 여행 정보를 찾을 수 없어요."
                    state.edit.isSaveUnavailableAlertPresented = true
                    return .none
                }
                state.materializeRecommendationRows()
                state.edit.isSaving = true
                let usedCourseIDs = Set(state.edit.draftPlacements.map(\.courseID))
                let courses = state.coursesByID.values
                    .filter { usedCourseIDs.contains($0.id) }
                    .sorted { $0.id < $1.id }
                    .map { course in
                        TripItinerarySaveRequest.Course(
                            id: course.id,
                            title: course.title,
                            placeNames: course.placeNames,
                            categories: course.categories,
                            memberIDs: course.members.map(\.rawValue),
                            durationMinutes: course.durationMinutes,
                            places: course.places
                        )
                    }
                let schedules = state.edit.draftPlacements.map { schedule in
                    TripItinerarySaveRequest.Schedule(
                        id: schedule.id,
                        courseID: schedule.courseID,
                        day: schedule.day.rawValue,
                        startMinuteOfDay: schedule.timing.startMinuteOfDay,
                        branchGroupID: schedule.branchGroupID
                    )
                }
                let request = TripItinerarySaveRequest(
                    tripID: tripID,
                    courses: courses,
                    schedules: schedules
                )
                return .run { send in
                    do {
                        try await tripClient.saveItinerary(request)
                        await send(.itinerarySaveSucceeded)
                    } catch {
                        await send(.itinerarySaveFailed(error.localizedDescription))
                    }
                }

            case let .edit(.scheduleTapped(id)):
                guard let schedule = state.edit.draftPlacements.first(where: {
                    $0.id == id && $0.day == state.selectedDay
                }) else { return .none }
                state.edit.editingScheduleID = id
                state.edit.placingGroupID = nil
                state.edit.editingDay = state.selectedDay
                state.edit.selectedMinuteOfDay = schedule.timing.startMinuteOfDay
                return .none

            case let .edit(.groupAddButtonTapped(id)):
                guard let group = state.unplacedGroups.first(where: { $0.id == id }),
                      Set(group.courseIDs).count == group.courseIDs.count,
                      group.courseIDs.allSatisfy({ state.coursesByID[$0] != nil }),
                      state.dayOfMonthByDay[state.selectedDay] != nil
                else { return .none }
                state.edit.placingGroupID = id
                state.edit.editingScheduleID = nil
                state.edit.editingDay = state.selectedDay
                state.edit.selectedMinuteOfDay = 12 * 60
                return .none

            case .edit(.timeSelectionDoneTapped):
                guard state.canConfirmTimeSelection,
                      let day = state.edit.editingDay,
                      day == state.selectedDay,
                      let minute = state.edit.selectedMinuteOfDay
                else { return .none }

                if let id = state.edit.editingScheduleID,
                   let index = state.edit.draftPlacements.firstIndex(where: {
                       $0.id == id && $0.day == day
                   }) {
                    state.edit.draftPlacements[index].timing.startMinuteOfDay = minute
                } else if let groupID = state.edit.placingGroupID,
                          let group = state.unplacedGroups.first(where: { $0.id == groupID }),
                          Set(group.courseIDs).count == group.courseIDs.count,
                          group.courseIDs.allSatisfy({ state.coursesByID[$0] != nil }) {
                    let nextScheduleID = (state.edit.draftPlacements.map(\.id).max() ?? -1) + 1
                    let nextBranchID = (state.edit.draftPlacements
                        .filter { $0.day == day }
                        .compactMap(\.branchGroupID)
                        .max() ?? -1) + 1
                    let newPlacements = group.courseIDs.enumerated().map { offset, courseID in
                        TimeTableSchedule(
                            id: nextScheduleID + offset,
                            courseID: courseID,
                            day: day,
                            timing: .init(startMinuteOfDay: minute),
                            branchGroupID: nextBranchID
                        )
                    }
                    state.edit.draftPlacements.append(contentsOf: newPlacements)
                    state.edit.rowsByDay[day, default: []].append(TimeTableEditRow(
                        id: "\(day.rawValue)-branch-\(nextBranchID)",
                        sources: newPlacements.map { .schedule($0.id) },
                        branchGroupID: "mock-\(nextBranchID)"
                    ))
                }
                state.edit.dismissTimeSelection()
                return .none

            case .edit:
                return .none

            case let .daySelected(day):
                state.selectedDay = state.availableDays.contains(day) ? day : .day1
                return .none
            }
        }
        Scope(state: \.edit, action: \.edit) {
            TimeTableEditFeature()
        }
    }

    private static func initialRows(
        on day: TripDay,
        placements: [TimeTableSchedule]
    ) -> [TimeTableEditRow] {
        let schedules = placements.filter { $0.day == day }
        var seenBranchIDs: Set<Int> = []
        var rows: [(minute: Int, index: Int, row: TimeTableEditRow)] = []

        for (index, schedule) in schedules.enumerated() {
            if let branchID = schedule.branchGroupID {
                guard seenBranchIDs.insert(branchID).inserted else { continue }
                let branch = schedules.filter { $0.branchGroupID == branchID }
                rows.append((
                    branch.map(\.timing.startMinuteOfDay).min() ?? 0,
                    index,
                    TimeTableEditRow(id: "\(day.rawValue)-branch-\(branchID)",
                                     sources: branch.map { .schedule($0.id) },
                                     branchGroupID: "mock-\(branchID)")
                ))
            } else {
                rows.append((
                    schedule.timing.startMinuteOfDay,
                    index,
                    TimeTableEditRow(id: "\(day.rawValue)-schedule-\(schedule.id)",
                                     sources: [.schedule(schedule.id)])
                ))
            }
        }

        return rows.sorted {
            $0.minute == $1.minute ? $0.index < $1.index : $0.minute < $1.minute
        }.map(\.row)
    }

    private static func memberIDs(for row: TimeTableEditRow, state: State) -> Set<String>? {
        var members: Set<String> = []
        for source in row.sources {
            let ids: [String]
            switch source {
            case let .schedule(id):
                guard let schedule = state.edit.draftPlacements.first(where: { $0.id == id }),
                      let course = state.coursesByID[schedule.courseID] else { return nil }
                ids = course.members.map(\.rawValue)
            case let .recommendationGroup(id):
                guard let recommendation = state.recommendations.first(where: { $0.groupID == id }) else { return nil }
                ids = recommendation.memberIDs
            }
            let courseMembers = Set(ids)
            guard !courseMembers.isEmpty, members.isDisjoint(with: courseMembers) else { return nil }
            members.formUnion(courseMembers)
        }
        return members
    }

    private static func memberIDs(
        for source: TimeTableEditRow.Source,
        state: State
    ) -> Set<String>? {
        switch source {
        case let .schedule(id):
            guard let schedule = state.edit.draftPlacements.first(where: { $0.id == id }),
                  let course = state.coursesByID[schedule.courseID]
            else { return nil }
            return Set(course.members.map(\.rawValue))

        case let .recommendationGroup(id):
            guard let recommendation = state.recommendations.first(where: { $0.groupID == id })
            else { return nil }
            return Set(recommendation.memberIDs)
        }
    }

    private static func rowID(
        for source: TimeTableEditRow.Source,
        on day: TripDay
    ) -> TimeTableEditRow.ID {
        switch source {
        case let .schedule(id): "\(day.rawValue)-schedule-\(id)"
        case let .recommendationGroup(id): "recommendation-\(id)"
        }
    }

    #if DEBUG
    static var debugMockState: State {
        var state = State()
        state.isLocalPreview = true
        state.tripTitle = "도쿄 여행을 살펴보게따"
        state.destinationName = "도쿄"
        let calendar = Calendar(identifier: .gregorian)
        state.tripStartDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 22))
        state.tripEndDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 25))
        state.recommendations = TimeTableRecommendation.debugTokyoRecommendations
        return state
    }

    static var debugEditPreviewState: State {
        var state = debugMockState
        state.edit.draftPlacements = state.placements
        for day in TripDay.allCases {
            state.edit.rowsByDay[day] = initialRows(on: day, placements: state.placements)
        }
        state.isEditing = true
        return state
    }
    #endif
}

struct TimeTableRecommendation: Equatable, Identifiable {
    let id: String
    let groupID: String
    let placeID: String
    let placeName: String
    let category: String
    var groupCategories: [String] = []
    let memberIDs: [String]
    let placeOwnerMemberIDs: [String]
    var latitude: Double = 0
    var longitude: Double = 0

    #if DEBUG
    static let debugTokyoRecommendations: [Self] = [
        Self(
            id: "debug-tokyo-stussy-debug-tokyo-place-stussy",
            groupID: "debug-tokyo-stussy",
            placeID: "debug-tokyo-place-stussy",
            placeName: "스투시 도쿄점",
            category: "쇼핑",
            memberIDs: [TripMember.grae.rawValue],
            placeOwnerMemberIDs: [TripMember.grae.rawValue]
        ),
        Self(
            id: "debug-tokyo-goods-debug-tokyo-place-goods",
            groupID: "debug-tokyo-goods",
            placeID: "debug-tokyo-place-goods",
            placeName: "물만두 굿즈샵",
            category: "쇼핑",
            memberIDs: [TripMember.juni.rawValue],
            placeOwnerMemberIDs: [TripMember.juni.rawValue]
        ),
        Self(
            id: "debug-tokyo-asakusa-debug-tokyo-place-sensoji",
            groupID: "debug-tokyo-asakusa",
            placeID: "debug-tokyo-place-sensoji",
            placeName: "센소지",
            category: "관광지",
            memberIDs: [TripMember.tae.rawValue, TripMember.header.rawValue],
            placeOwnerMemberIDs: [TripMember.tae.rawValue]
        ),
        Self(
            id: "debug-tokyo-asakusa-debug-tokyo-place-nakamise",
            groupID: "debug-tokyo-asakusa",
            placeID: "debug-tokyo-place-nakamise",
            placeName: "나카미세도리",
            category: "관광지",
            memberIDs: [TripMember.tae.rawValue, TripMember.header.rawValue],
            placeOwnerMemberIDs: [TripMember.header.rawValue]
        )
    ]
    #endif
}

extension Collection where Element == TimeTableRecommendation {
    var categoryValues: [String] {
        reduce(into: [String]()) { result, recommendation in
            let values = recommendation.groupCategories.isEmpty
                ? [recommendation.category]
                : recommendation.groupCategories
            for category in values where !category.isEmpty && !result.contains(category) {
                result.append(category)
            }
        }
    }

    var categorySummary: String {
        categoryValues.joined(separator: ", ")
    }
}

enum TripDay: String, CaseIterable, Equatable, Identifiable {
    case day1 = "DAY 1"
    case day2 = "DAY 2"
    case day3 = "DAY 3"
    case day4 = "DAY 4"

    var id: Self { self }
}

struct TimeTableGroup: Equatable, Identifiable {
    let id: Int
    let name: String
    let courseIDs: [TimeTableCourse.ID]

    func participantSummary(in coursesByID: [TimeTableCourse.ID: TimeTableCourse]) -> String {
        courseIDs.compactMap { coursesByID[$0]?.members.count }
            .map { "\($0)명" }
            .joined(separator: " · ")
    }
}

struct TimeTableCourse: Equatable, Identifiable {
    enum Kind: Equatable {
        case separate
        case together
    }

    let id: Int
    let title: String
    let placeCount: Int
    let placeNames: [String]
    let categories: [String]
    let members: [TripMember]
    let durationMinutes: Int
    let places: [ItineraryPlace]

    init(
        id: Int,
        title: String,
        placeCount: Int,
        placeNames: [String],
        categories: [String] = [],
        members: [TripMember],
        durationMinutes: Int,
        places: [ItineraryPlace] = []
    ) {
        self.id = id
        self.title = title
        self.placeCount = placeCount
        self.placeNames = placeNames
        self.categories = categories
        self.members = members
        self.durationMinutes = durationMinutes
        self.places = places
    }

    func kind(among tripMembers: [TripMember]) -> Kind? {
        let tripMemberIDs = tripMembers.map(\.id)
        let courseMemberIDs = members.map(\.id)
        let tripIDSet = Set(tripMemberIDs)
        let courseIDSet = Set(courseMemberIDs)

        guard !tripIDSet.isEmpty,
              !courseIDSet.isEmpty,
              tripIDSet.count == tripMemberIDs.count,
              courseIDSet.count == courseMemberIDs.count,
              courseIDSet.isSubset(of: tripIDSet)
        else { return nil }

        return courseIDSet == tripIDSet ? .together : .separate
    }

    var placesSummary: String {
        let displayedNames = Array(placeNames.prefix(2))
        let remainingCount = max(placeCount - displayedNames.count, 0)
        let names = displayedNames.joined(separator: ", ")
        return remainingCount > 0 ? "\(names) 외 \(remainingCount)곳" : names
    }

    var categorySummary: String {
        categories.reduce(into: [String]()) { result, category in
            guard !category.isEmpty, !result.contains(category) else { return }
            result.append(category)
        }
        .joined(separator: ", ")
    }

    static let mockCoursesByID: [ID: Self] = {
        let courses: [Self] = [
            .init(id: 0, title: "도쿄역 쇼핑 코스", placeCount: 4, placeNames: ["TK 빈티지샵", "HABARI"], members: [.tae, .header], durationMinutes: 240),
            .init(id: 1, title: "치이카와 뮤지엄 코스", placeCount: 4, placeNames: ["치이카와랜드"], members: [.grae, .juni], durationMinutes: 240),
            .init(id: 2, title: "파르페 먹방 코스", placeCount: 4, placeNames: ["말차 파르페 센터"], members: [.grae, .header, .juni, .tae], durationMinutes: 210),
            .init(id: 100, title: "아사쿠사 산책 코스", placeCount: 3, placeNames: ["센소지", "나카미세도리"], members: [.tae, .juni], durationMinutes: 180),
            .init(id: 101, title: "우에노 문화 코스", placeCount: 4, placeNames: ["우에노 공원", "도쿄 국립박물관"], members: [.header, .grae], durationMinutes: 240),
            .init(id: 102, title: "아키하바라 야경 코스", placeCount: 3, placeNames: ["아키하바라 전자상가"], members: TripMember.allCases, durationMinutes: 180),
            .init(id: 200, title: "하라주쿠 쇼핑 코스", placeCount: 4, placeNames: ["타케시타도리", "캐트스트리트"], members: [.tae, .grae], durationMinutes: 240),
            .init(id: 201, title: "시부야 디저트 코스", placeCount: 3, placeNames: ["하치 카페"], members: [.header, .juni], durationMinutes: 180),
            .init(id: 202, title: "시부야 야경 코스", placeCount: 3, placeNames: ["시부야 스카이"], members: TripMember.allCases, durationMinutes: 180),
            .init(id: 302, title: "긴자 브런치 코스", placeCount: 2, placeNames: ["긴자 카페"], members: [.tae], durationMinutes: 120),
            .init(id: 303, title: "도쿄역 마지막 쇼핑", placeCount: 3, placeNames: ["도쿄 캐릭터스트리트"], members: [.header, .grae, .juni], durationMinutes: 120),
            .init(id: 300, title: "긴자 브런치 코스", placeCount: 2, placeNames: ["긴자 카페"], members: TripMember.allCases, durationMinutes: 120),
            .init(id: 301, title: "도쿄역 마지막 쇼핑", placeCount: 3, placeNames: ["도쿄 캐릭터스트리트"], members: TripMember.allCases, durationMinutes: 180),
            .init(id: 400, title: "신주쿠 쇼핑 코스", placeCount: 2, placeNames: ["루미네 신주쿠", "이세탄 신주쿠"], members: [.grae, .juni], durationMinutes: 240),
            .init(id: 401, title: "신주쿠 카페 코스", placeCount: 2, placeNames: ["카페 알리야", "신주쿠 교엔"], members: [.tae], durationMinutes: 120),
            .init(id: 402, title: "주오 맛집 투어", placeCount: 2, placeNames: ["오이시 돈코츠 라멘", "말차 카페"], members: TripMember.allCases, durationMinutes: 240)
        ]
        return Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0) })
    }()
}

struct TimeTableSchedule: Equatable, Identifiable {
    let id: Int
    let courseID: TimeTableCourse.ID
    let day: TripDay
    var timing: TimeTableScheduleTiming
    let branchGroupID: Int?

    static func hasTimeConflict(
        courseIDs: [TimeTableCourse.ID],
        startingAt minute: Int,
        on day: TripDay,
        excluding scheduleID: ID?,
        placements: [Self],
        coursesByID: [TimeTableCourse.ID: TimeTableCourse]
    ) -> Bool {
        let proposed = courseIDs.compactMap { courseID in
            coursesByID[courseID].map {
                TimeTableOccupiedInterval(start: minute, course: $0)
            }
        }
        guard proposed.count == courseIDs.count else { return false }

        let existing = placements.compactMap { schedule -> TimeTableOccupiedInterval? in
            guard schedule.day == day,
                  schedule.id != scheduleID,
                  let course = coursesByID[schedule.courseID]
            else { return nil }
            return TimeTableOccupiedInterval(
                start: schedule.timing.startMinuteOfDay,
                course: course
            )
        }

        for index in proposed.indices {
            if existing.contains(where: { proposed[index].conflicts(with: $0) }) {
                return true
            }
            for otherIndex in proposed.indices where otherIndex > index {
                if proposed[index].conflicts(with: proposed[otherIndex]) {
                    return true
                }
            }
        }
        return false
    }

}

private struct TimeTableOccupiedInterval {
    let start: Int
    let end: Int
    let memberIDs: Set<TripMember.ID>

    init(start: Int, course: TimeTableCourse) {
        self.start = start
        end = start + course.durationMinutes
        memberIDs = Set(course.members.map(\.id))
    }

    func conflicts(with other: Self) -> Bool {
        start < other.end && other.start < end &&
        !memberIDs.isDisjoint(with: other.memberIDs)
    }
}

struct TimeTableScheduleTiming: Equatable {
    var startMinuteOfDay: Int

    init(startHour: Int, startMinute: Int) {
        startMinuteOfDay = startHour * 60 + startMinute
    }

    init(startMinuteOfDay: Int) {
        self.startMinuteOfDay = startMinuteOfDay
    }

    func displayText(dayOfMonth: Int, durationMinutes: Int) -> String {
        let endMinuteOfDay = startMinuteOfDay + durationMinutes
        let endDayOffset = endMinuteOfDay / 1440
        let endDay = endDayOffset == 0 ? "" : "\(dayOfMonth + endDayOffset)일 "
        return "\(dayOfMonth)일 \(formatted(startMinuteOfDay)) ~ \(endDay)\(formatted(endMinuteOfDay % 1440))"
    }

    private func formatted(_ minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}
