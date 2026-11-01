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
        let groups = TimeTableGroup.mockGroups
        var schedulesByDay = TimeTableSchedule.mockSchedulesByDay
        var isEditing = false
        var edit = TimeTableEditFeature.State()

        var schedules: [TimeTableSchedule] {
            schedulesByDay[selectedDay, default: []].sorted {
                $0.timing.startMinuteOfDay < $1.timing.startMinuteOfDay
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
                guard let schedule = state.schedulesByDay[state.selectedDay]?.first(where: { $0.id == id })
                else { return .none }
                state.edit.editingScheduleID = id
                state.edit.editingDay = state.selectedDay
                state.edit.selectedMinuteOfDay = schedule.timing.startMinuteOfDay
                return .none

            case .edit(.timeSelectionDoneTapped):
                guard let day = state.edit.editingDay,
                      day == state.selectedDay,
                      let id = state.edit.editingScheduleID,
                      let minute = state.edit.selectedMinuteOfDay,
                      let index = state.schedulesByDay[day]?.firstIndex(where: { $0.id == id })
                else { return .none }
                state.schedulesByDay[day]?[index].timing.startMinuteOfDay = minute
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
    let participantCounts: [Int]

    var participantSummary: String {
        participantCounts.map { "\($0)명" }.joined(separator: " · ")
    }

    static let mockGroups = [
        TimeTableGroup(id: 0, name: "신주쿠", participantCounts: [2, 1]),
        TimeTableGroup(id: 1, name: "주오", participantCounts: [4])
    ]
}

struct TimeTableSchedule: Equatable, Identifiable {
    enum Kind: Equatable {
        case separate
        case together
    }

    let id: Int
    let title: String
    let placeCount: Int
    var timing: TimeTableScheduleTiming
    let placeNames: [String]
    let members: [TripMember]
    var branchGroupID: Int?

    var time: String { timing.displayText }

    func kind(among tripMembers: [TripMember]) -> Kind? {
        let tripMemberIDs = tripMembers.map(\.id)
        let scheduleMemberIDs = members.map(\.id)
        let tripIDSet = Set(tripMemberIDs)
        let scheduleIDSet = Set(scheduleMemberIDs)

        guard !tripIDSet.isEmpty,
              !scheduleIDSet.isEmpty,
              tripIDSet.count == tripMemberIDs.count,
              scheduleIDSet.count == scheduleMemberIDs.count,
              scheduleIDSet.isSubset(of: tripIDSet)
        else { return nil }

        return scheduleIDSet == tripIDSet ? .together : .separate
    }

    var placesSummary: String {
        let displayedNames = Array(placeNames.prefix(2))
        let remainingCount = max(placeCount - displayedNames.count, 0)
        let names = displayedNames.joined(separator: ", ")
        return remainingCount > 0 ? "\(names) 외 \(remainingCount)곳" : names
    }

    static let mockSchedulesByDay: [TripDay: [TimeTableSchedule]] = [
        .day1: [
            TimeTableSchedule(id: 0, title: "도쿄역 쇼핑 코스", placeCount: 4, timing: .init(dayOfMonth: 22, startHour: 10, startMinute: 0, durationMinutes: 240), placeNames: ["TK 빈티지샵", "HABARI"], members: [.tae, .header]),
            TimeTableSchedule(id: 1, title: "치이카와 뮤지엄 코스", placeCount: 4, timing: .init(dayOfMonth: 22, startHour: 10, startMinute: 0, durationMinutes: 240), placeNames: ["치이카와랜드"], members: [.grae, .juni]),
            TimeTableSchedule(id: 2, title: "파르페 먹방 코스", placeCount: 4, timing: .init(dayOfMonth: 22, startHour: 14, startMinute: 30, durationMinutes: 210), placeNames: ["말차 파르페 센터"], members: [.grae, .header, .juni, .tae])
        ],
        .day2: [
            TimeTableSchedule(id: 100, title: "아사쿠사 산책 코스", placeCount: 3, timing: .init(dayOfMonth: 23, startHour: 9, startMinute: 30, durationMinutes: 180), placeNames: ["센소지", "나카미세도리"], members: [.tae, .juni]),
            TimeTableSchedule(id: 101, title: "우에노 문화 코스", placeCount: 4, timing: .init(dayOfMonth: 23, startHour: 13, startMinute: 0, durationMinutes: 240), placeNames: ["우에노 공원", "도쿄 국립박물관"], members: [.header, .grae]),
            TimeTableSchedule(id: 102, title: "아키하바라 야경 코스", placeCount: 3, timing: .init(dayOfMonth: 23, startHour: 18, startMinute: 0, durationMinutes: 180), placeNames: ["아키하바라 전자상가"], members: TripMember.allCases)
        ],
        .day3: [
            TimeTableSchedule(id: 200, title: "하라주쿠 쇼핑 코스", placeCount: 4, timing: .init(dayOfMonth: 24, startHour: 10, startMinute: 0, durationMinutes: 240), placeNames: ["타케시타도리", "캐트스트리트"], members: [.tae, .grae]),
            TimeTableSchedule(id: 201, title: "시부야 디저트 코스", placeCount: 3, timing: .init(dayOfMonth: 24, startHour: 14, startMinute: 30, durationMinutes: 180), placeNames: ["하치 카페"], members: [.header, .juni]),
            TimeTableSchedule(id: 202, title: "시부야 야경 코스", placeCount: 3, timing: .init(dayOfMonth: 24, startHour: 19, startMinute: 0, durationMinutes: 180), placeNames: ["시부야 스카이"], members: TripMember.allCases)
        ],
        .day4: [
            TimeTableSchedule(id: 302, title: "긴자 브런치 코스", placeCount: 2, timing: .init(dayOfMonth: 25, startHour: 9, startMinute: 0, durationMinutes: 120), placeNames: ["긴자 카페"], members: [.tae], branchGroupID: 0),
            TimeTableSchedule(id: 303, title: "도쿄역 마지막 쇼핑", placeCount: 3, timing: .init(dayOfMonth: 25, startHour: 9, startMinute: 0, durationMinutes: 120), placeNames: ["도쿄 캐릭터스트리트"], members: [.header, .grae, .juni], branchGroupID: 0),
            TimeTableSchedule(id: 300, title: "긴자 브런치 코스", placeCount: 2, timing: .init(dayOfMonth: 25, startHour: 9, startMinute: 0, durationMinutes: 120), placeNames: ["긴자 카페"], members: TripMember.allCases),
            TimeTableSchedule(id: 301, title: "도쿄역 마지막 쇼핑", placeCount: 3, timing: .init(dayOfMonth: 25, startHour: 11, startMinute: 30, durationMinutes: 180), placeNames: ["도쿄 캐릭터스트리트"], members: TripMember.allCases)
        ]
    ]
}

struct TimeTableScheduleTiming: Equatable {
    let dayOfMonth: Int
    var startMinuteOfDay: Int
    let durationMinutes: Int

    init(dayOfMonth: Int, startHour: Int, startMinute: Int, durationMinutes: Int) {
        self.dayOfMonth = dayOfMonth
        self.startMinuteOfDay = startHour * 60 + startMinute
        self.durationMinutes = durationMinutes
    }

    var displayText: String {
        let endMinuteOfDay = startMinuteOfDay + durationMinutes
        let endDayOffset = endMinuteOfDay / 1440
        let endDay = endDayOffset == 0 ? "" : "\(dayOfMonth + endDayOffset)일 "
        return "\(dayOfMonth)일 \(formatted(startMinuteOfDay)) ~ \(endDay)\(formatted(endMinuteOfDay % 1440))"
    }

    private func formatted(_ minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}
