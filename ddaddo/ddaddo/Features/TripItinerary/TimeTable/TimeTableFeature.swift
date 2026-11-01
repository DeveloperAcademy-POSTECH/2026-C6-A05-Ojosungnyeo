//
//  TimeTableFeature.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture
import Foundation

struct TimeTableFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var selectedDay = TripDay.day1
        var tripMembers = TripMember.allCases
        var dayOfMonthByDay: [TripDay: Int] = [
            .day1: 22, .day2: 23, .day3: 24, .day4: 25
        ]
        var coursesByID = TimeTableCourse.mockCoursesByID
        var groups = TimeTableGroup.mockGroups
        var placements = TimeTableSchedule.mockPlacements
        var isEditing = false
        var edit = TimeTableEditFeature.State()

        var unplacedGroups: [TimeTableGroup] {
            let placedCourseIDs = Set(placements.map(\.courseID))
            return groups.filter { group in
                !group.courseIDs.isEmpty &&
                group.courseIDs.allSatisfy { !placedCourseIDs.contains($0) }
            }
        }

        var timeSelectionCourseIDs: [TimeTableCourse.ID]? {
            guard let day = edit.editingDay, day == selectedDay else { return nil }

            if let scheduleID = edit.editingScheduleID {
                return placements.first(where: { $0.id == scheduleID && $0.day == day })
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
                placements: placements,
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

    }

    @CasePathable
    enum Action: Equatable {
        case backButtonTapped
        case editButtonTapped
        case daySelected(TripDay)
        case groupAddButtonTapped(TimeTableGroup.ID)
        case scheduleTapped(TimeTableSchedule.ID)
        case edit(TimeTableEditFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped, .groupAddButtonTapped, .scheduleTapped:
                return .none

            case .editButtonTapped:
                state.isEditing = true
                return .none

            case .edit(.backButtonTapped), .edit(.saveButtonTapped):
                state.isEditing = false
                return .none

            case let .edit(.scheduleTapped(id)):
                guard let schedule = state.placements.first(where: {
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
                   let index = state.placements.firstIndex(where: {
                       $0.id == id && $0.day == day
                   }) {
                    state.placements[index].timing.startMinuteOfDay = minute
                } else if let groupID = state.edit.placingGroupID,
                          let group = state.unplacedGroups.first(where: { $0.id == groupID }),
                          Set(group.courseIDs).count == group.courseIDs.count,
                          group.courseIDs.allSatisfy({ state.coursesByID[$0] != nil }) {
                    let nextScheduleID = (state.placements.map(\.id).max() ?? -1) + 1
                    let nextBranchID = (state.placements
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
                    state.placements.append(contentsOf: newPlacements)
                }
                state.edit.dismissTimeSelection()
                return .none

            case .edit:
                return .none

            case let .daySelected(day):
                state.selectedDay = day
                return .none
            }
        }
        Scope(state: \.edit, action: \.edit) {
            TimeTableEditFeature()
        }
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

    static let mockGroups = [
        TimeTableGroup(id: 0, name: "신주쿠", courseIDs: [400, 401]),
        TimeTableGroup(id: 1, name: "주오", courseIDs: [402])
    ]
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
    let members: [TripMember]
    let durationMinutes: Int

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

    static let mockPlacements: [Self] = [
        .init(id: 0, courseID: 0, day: .day1, timing: .init(startHour: 10, startMinute: 0), branchGroupID: 0),
        .init(id: 1, courseID: 1, day: .day1, timing: .init(startHour: 10, startMinute: 0), branchGroupID: 0),
        .init(id: 2, courseID: 2, day: .day1, timing: .init(startHour: 14, startMinute: 30), branchGroupID: nil),
        .init(id: 100, courseID: 100, day: .day2, timing: .init(startHour: 9, startMinute: 30), branchGroupID: 0),
        .init(id: 101, courseID: 101, day: .day2, timing: .init(startHour: 13, startMinute: 0), branchGroupID: 0),
        .init(id: 102, courseID: 102, day: .day2, timing: .init(startHour: 18, startMinute: 0), branchGroupID: nil),
        .init(id: 200, courseID: 200, day: .day3, timing: .init(startHour: 10, startMinute: 0), branchGroupID: 0),
        .init(id: 201, courseID: 201, day: .day3, timing: .init(startHour: 14, startMinute: 30), branchGroupID: 0),
        .init(id: 202, courseID: 202, day: .day3, timing: .init(startHour: 19, startMinute: 0), branchGroupID: nil),
        .init(id: 302, courseID: 302, day: .day4, timing: .init(startHour: 9, startMinute: 0), branchGroupID: 0),
        .init(id: 303, courseID: 303, day: .day4, timing: .init(startHour: 9, startMinute: 0), branchGroupID: 0),
        .init(id: 300, courseID: 300, day: .day4, timing: .init(startHour: 9, startMinute: 0), branchGroupID: nil),
        .init(id: 301, courseID: 301, day: .day4, timing: .init(startHour: 11, startMinute: 30), branchGroupID: nil)
    ]
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
