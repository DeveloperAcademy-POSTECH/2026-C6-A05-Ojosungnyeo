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
        let groups = TimeTableGroup.mockGroups
        let schedulesByDay = TimeTableSchedule.mockSchedulesByDay
        var isAddSchedulePresented = false
        var placeSearchText = ""
        var placeSearchResults: [PlaceSearchResult] = []
        var isPlaceSearchLoading = false
        var placeSearchErrorMessage: String?

        var schedules: [TimeTableSchedule] {
            schedulesByDay[selectedDay, default: []]
        }
    }

    enum Action: Equatable {
        case backButtonTapped
        case editButtonTapped
        case daySelected(TripDay)
        case groupAddButtonTapped(TimeTableGroup.ID)
        case scheduleTapped(TimeTableSchedule.ID)
        case addScheduleButtonTapped
        case addScheduleDismissed
        case placeSearchTextChanged(String)
        case placeSearchResponse([PlaceSearchResult])
        case placeSearchFailed(String)
        case placeSearchResultTapped(PlaceSearchResult)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.placeClient) var placeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped, .editButtonTapped,
                 .groupAddButtonTapped, .scheduleTapped,
                 .placeSearchResultTapped:
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

            case let .daySelected(day):
                state.selectedDay = day
                return .none
            }
        }
    }

    private func searchPlaces(
        query: String,
        debounce: Bool
    ) -> Effect<Action> {
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

enum TripDay: String, CaseIterable, Equatable, Identifiable {
    case day1 = "DAY 1"
    case day2 = "DAY 2"
    case day3 = "DAY 3"
    case day4 = "DAY 4"

    var id: Self { self }
}

struct TimeTableGroup: Equatable, Identifiable {
    let id: Int
    let city: String
    let memberNames: String
    let placeName: String

    static let mockGroups = [
        TimeTableGroup(id: 0, city: "도쿄", memberNames: "테이", placeName: "BUBU 베이커리"),
        TimeTableGroup(id: 1, city: "도쿄", memberNames: "주니, 헤더", placeName: "KY 센터"),
        TimeTableGroup(id: 2, city: "도쿄", memberNames: "그레", placeName: "말차 파르페 센터"),
        TimeTableGroup(id: 3, city: "도쿄", memberNames: "테이", placeName: "HABARI")
    ]
}

struct TimeTableSchedule: Equatable, Identifiable {
    let id: Int
    let title: String
    let placeCount: Int
    let time: String
    let places: String
    let members: [TripMember]

    static let mockSchedulesByDay: [TripDay: [TimeTableSchedule]] = [
        .day1: [
            TimeTableSchedule(id: 0, title: "도쿄역 쇼핑 코스", placeCount: 4, time: "22일 10:00 ~ 14:00", places: "TK 빈티지샵, HABARI 외 2곳", members: [.tae, .header]),
            TimeTableSchedule(id: 1, title: "치이카와 뮤지엄 코스", placeCount: 4, time: "22일 10:00 ~ 14:00", places: "치이카와랜드 외 3곳", members: [.grae, .juni]),
            TimeTableSchedule(id: 2, title: "파르페 먹방 코스", placeCount: 4, time: "22일 14:30 ~ 18:00", places: "말차 파르페 센터 외 3곳", members: [.grae])
        ],
        .day2: [
            TimeTableSchedule(id: 100, title: "아사쿠사 산책 코스", placeCount: 3, time: "23일 09:30 ~ 12:30", places: "센소지, 나카미세도리 외 1곳", members: [.tae, .juni]),
            TimeTableSchedule(id: 101, title: "우에노 문화 코스", placeCount: 4, time: "23일 13:00 ~ 17:00", places: "우에노 공원, 도쿄 국립박물관 외 2곳", members: [.header, .grae]),
            TimeTableSchedule(id: 102, title: "아키하바라 야경 코스", placeCount: 3, time: "23일 18:00 ~ 21:00", places: "아키하바라 전자상가 외 2곳", members: TripMember.allCases)
        ],
        .day3: [
            TimeTableSchedule(id: 200, title: "하라주쿠 쇼핑 코스", placeCount: 4, time: "24일 10:00 ~ 14:00", places: "타케시타도리, 캐트스트리트 외 2곳", members: [.tae, .grae]),
            TimeTableSchedule(id: 201, title: "시부야 디저트 코스", placeCount: 3, time: "24일 14:30 ~ 17:30", places: "하치 카페 외 2곳", members: [.header, .juni]),
            TimeTableSchedule(id: 202, title: "시부야 야경 코스", placeCount: 3, time: "24일 19:00 ~ 22:00", places: "시부야 스카이 외 2곳", members: TripMember.allCases)
        ],
        .day4: [
            TimeTableSchedule(id: 300, title: "긴자 브런치 코스", placeCount: 2, time: "25일 09:00 ~ 11:00", places: "긴자 카페 외 1곳", members: TripMember.allCases),
            TimeTableSchedule(id: 301, title: "도쿄역 마지막 쇼핑", placeCount: 3, time: "25일 11:30 ~ 14:30", places: "도쿄 캐릭터스트리트 외 2곳", members: TripMember.allCases)
        ]
    ]
}
