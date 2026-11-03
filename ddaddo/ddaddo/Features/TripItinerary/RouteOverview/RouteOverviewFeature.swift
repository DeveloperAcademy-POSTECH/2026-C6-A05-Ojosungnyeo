//
//  RouteOverviewFeature.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture
import CoreGraphics

struct RouteOverviewFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var selectedDay = TripDay.day1
        var selectedMembers: Set<TripMember> = []
        var selectedPlaceID: RoutePlace.ID? = RoutePlace.mockPlaces[1].id
        var isEditing = false
        var stopsByDay = RouteStop.stopsByDay
        var draftStopsByDay: [TripDay: [RouteStop]]?
        let places = RoutePlace.mockPlaces
        let currentMember = TripMember.tae

        private var currentStops: [RouteStop] {
            let source = draftStopsByDay ?? stopsByDay
            return source[selectedDay, default: []]
        }

        var visibleStopGroups: [RouteStopGroup] {
            let stops: [RouteStop]
            if selectedMembers.isEmpty {
                stops = currentStops
            } else {
                stops = currentStops.filter { !$0.members.isDisjoint(with: selectedMembers) }
            }

            return Dictionary(grouping: stops, by: \.order)
                .map { RouteStopGroup(id: $0.key, stops: $0.value) }
                .sorted { $0.id < $1.id }
        }

        var visibleStops: [RouteStop] {
            visibleStopGroups.flatMap(\.stops)
        }

        var selectedPlace: RoutePlace {
            places.first { $0.id == selectedPlaceID } ?? places[0]
        }
    }

    enum Action: Equatable {
        case onAppear
        case backButtonTapped
        case daySelected(TripDay)
        case memberTapped(TripMember)
        case editButtonTapped
        case editingDoneButtonTapped
        case editingStopMoved(RouteStop.ID, before: RouteStop.ID)
        case editingStopDeleted(RouteStop.ID)
        case placeChanged(RoutePlace.ID?)
        case addressCopyButtonTapped(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.selectedDay = .day1
                state.selectedMembers.removeAll()
                state.isEditing = false
                state.draftStopsByDay = nil
                return .none

            case .backButtonTapped:
                return .none

            case let .daySelected(day):
                state.selectedDay = day
                return .none

            case let .memberTapped(member):
                if state.selectedMembers.contains(member) {
                    state.selectedMembers.remove(member)
                } else {
                    state.selectedMembers.insert(member)
                }
                return .none

            case .editButtonTapped:
                state.draftStopsByDay = state.stopsByDay
                state.isEditing = true
                return .none

            case .editingDoneButtonTapped:
                if let draftStopsByDay = state.draftStopsByDay {
                    state.stopsByDay = draftStopsByDay
                }
                state.draftStopsByDay = nil
                state.isEditing = false
                return .none

            case let .editingStopMoved(sourceID, targetID):
                state.moveDraftGroup(containing: sourceID, before: targetID)
                return .none

            case let .editingStopDeleted(stopID):
                state.deleteDraftStop(stopID)
                return .none

            case let .placeChanged(placeID):
                guard let placeID else { return .none }
                state.selectedPlaceID = placeID
                return .none

            case .addressCopyButtonTapped:
                return .none
            }
        }
    }
}

private extension RouteOverviewFeature.State {
    mutating func moveDraftGroup(
        containing sourceID: RouteStop.ID,
        before targetID: RouteStop.ID
    ) {
        guard var draftStopsByDay,
              let dayStops = draftStopsByDay[selectedDay],
              let sourceStop = dayStops.first(where: { $0.id == sourceID }),
              let targetStop = dayStops.first(where: { $0.id == targetID }),
              sourceStop.order != targetStop.order else { return }

        var groups = Dictionary(grouping: dayStops, by: \.order)
            .sorted { $0.key < $1.key }
            .map(\.value)

        guard let sourceIndex = groups.firstIndex(where: { group in
            group.contains(where: { $0.id == sourceID })
        }),
        let targetIndex = groups.firstIndex(where: { group in
            group.contains(where: { $0.id == targetID })
        }) else { return }

        let movingGroup = groups.remove(at: sourceIndex)
        let insertionIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        groups.insert(movingGroup, at: insertionIndex)
        draftStopsByDay[selectedDay] = normalized(groups: groups)
        self.draftStopsByDay = draftStopsByDay
    }

    mutating func deleteDraftStop(_ stopID: RouteStop.ID) {
        guard var draftStopsByDay,
              let dayStops = draftStopsByDay[selectedDay] else { return }

        let remainingStops = dayStops.filter { $0.id != stopID }
        let groups = Dictionary(grouping: remainingStops, by: \.order)
            .sorted { $0.key < $1.key }
            .map(\.value)
        draftStopsByDay[selectedDay] = normalized(groups: groups)
        self.draftStopsByDay = draftStopsByDay
    }

    func normalized(groups: [[RouteStop]]) -> [RouteStop] {
        groups.enumerated().flatMap { order, group in
            group.map { $0.with(order: order) }
        }
    }
}

struct RouteStopGroup: Equatable, Identifiable {
    let id: Int
    let stops: [RouteStop]
}

struct RouteStop: Equatable, Identifiable {
    let id: Int
    let order: Int
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double
    let members: Set<TripMember>

    func with(order: Int) -> Self {
        RouteStop(
            id: id,
            order: order,
            name: name,
            category: category,
            latitude: latitude,
            longitude: longitude,
            members: members
        )
    }

    static let stopsByDay: [TripDay: [RouteStop]] = [
        .day1: [
            RouteStop(id: 0, order: 0, name: "시부야 스카이", category: "전망대", latitude: 35.6584, longitude: 139.7016, members: Set(TripMember.allCases)),
            RouteStop(id: 1, order: 1, name: "시부야 PARCO", category: "쇼핑", latitude: 35.6620, longitude: 139.6987, members: Set(TripMember.allCases)),
            RouteStop(id: 2, order: 2, name: "요요기 공원", category: "공원·정원", latitude: 35.6717, longitude: 139.6949, members: [.grae, .juni]),
            RouteStop(id: 3, order: 2, name: "오모테산도 힐즈", category: "쇼핑", latitude: 35.6672, longitude: 139.7088, members: [.tae, .header]),
            RouteStop(id: 4, order: 3, name: "다케시타 거리", category: "쇼핑", latitude: 35.6713, longitude: 139.7030, members: Set(TripMember.allCases)),
            RouteStop(id: 5, order: 4, name: "메이지 신궁", category: "역사·종교", latitude: 35.6764, longitude: 139.6993, members: Set(TripMember.allCases))
        ],
        .day2: [
            RouteStop(id: 10, order: 0, name: "츠키지 장외시장", category: "맛집", latitude: 35.6655, longitude: 139.7707, members: Set(TripMember.allCases)),
            RouteStop(id: 11, order: 1, name: "기요스미 정원", category: "공원·정원", latitude: 35.6780, longitude: 139.7974, members: Set(TripMember.allCases)),
            RouteStop(id: 12, order: 2, name: "센소지", category: "역사·종교", latitude: 35.7148, longitude: 139.7967, members: Set(TripMember.allCases)),
            RouteStop(id: 13, order: 3, name: "갓파바시 도구거리", category: "쇼핑", latitude: 35.7119, longitude: 139.7907, members: Set(TripMember.allCases)),
            RouteStop(id: 14, order: 4, name: "아메요코 시장", category: "시장 · 맛집", latitude: 35.7090, longitude: 139.7745, members: Set(TripMember.allCases))
        ],
        .day3: [
            RouteStop(id: 20, order: 0, name: "지브리 미술관", category: "박물관", latitude: 35.6962, longitude: 139.5704, members: [.grae, .juni]),
            RouteStop(id: 21, order: 0, name: "네즈 미술관", category: "미술관", latitude: 35.6622, longitude: 139.7170, members: [.tae, .header]),
            RouteStop(id: 22, order: 1, name: "하모니카 요코초", category: "맛집", latitude: 35.7030, longitude: 139.5795, members: [.grae, .juni]),
            RouteStop(id: 23, order: 1, name: "오모테산도", category: "쇼핑", latitude: 35.6650, longitude: 139.7126, members: [.tae, .header]),
            RouteStop(id: 24, order: 2, name: "나카노 브로드웨이", category: "쇼핑", latitude: 35.7091, longitude: 139.6657, members: [.grae, .juni]),
            RouteStop(id: 25, order: 2, name: "21_21 디자인 사이트", category: "미술관", latitude: 35.6664, longitude: 139.7306, members: [.tae, .header]),
            RouteStop(id: 26, order: 3, name: "시부야 PARCO", category: "쇼핑", latitude: 35.6620, longitude: 139.6987, members: Set(TripMember.allCases)),
            RouteStop(id: 27, order: 4, name: "시부야 스카이", category: "전망대", latitude: 35.6584, longitude: 139.7016, members: Set(TripMember.allCases)),
            RouteStop(id: 28, order: 5, name: "시부야 저녁", category: "맛집", latitude: 35.6604, longitude: 139.7006, members: Set(TripMember.allCases))
        ],
        .day4: [
            RouteStop(id: 30, order: 0, name: "신주쿠 오전 일정", category: "관광지", latitude: 35.6852, longitude: 139.7100, members: Set(TripMember.allCases)),
            RouteStop(id: 31, order: 1, name: "숙소에서 짐 수령", category: "숙소", latitude: 35.6938, longitude: 139.7034, members: Set(TripMember.allCases)),
            RouteStop(id: 32, order: 2, name: "하네다공항", category: "공항", latitude: 35.5494, longitude: 139.7798, members: Set(TripMember.allCases))
        ]
    ]
}

struct RoutePlace: Equatable, Identifiable {
    enum RouteType: Equatable {
        case together
        case separate

        var mapImageName: String {
            switch self {
            case .together: "DDRouteOverviewTogetherMap"
            case .separate: "DDRouteOverviewMap"
            }
        }

        var mapAspectRatio: CGFloat {
            switch self {
            case .together: 663 / 884
            case .separate: 1064 / 1478
            }
        }

        var mapLeadingOffsetRatio: CGFloat {
            switch self {
            case .together: -23 / 884
            case .separate: -85 / 874
            }
        }
    }

    let id: Int
    let name: String
    let description: String
    let address: String
    let members: [TripMember]
    let routeType: RouteType

    static let mockPlaces = [
        RoutePlace(
            id: 0,
            name: "TK 라멘",
            description: "도쿄 제일 가는 라멘 맛집",
            address: "WITH HARAJUKU B1, 1 Chome-14-30 Jingumae, Shibuya, Tokyo 150-0001, Japan",
            members: TripMember.allCases,
            routeType: .together
        ),
        RoutePlace(
            id: 1,
            name: "도쿄 꽃시장",
            description: "다양한 꽃을 살 수 있는 곳",
            address: "WITH HARAJUKU B1, 1 Chome-14-30 Jingumae, Shibuya, Tokyo 150-0001, Japan",
            members: [.header, .grae],
            routeType: .separate
        ),
        RoutePlace(
            id: 2,
            name: "피카츄 도서관",
            description: "포켓몬스터 팬을 위한 도서관",
            address: "WITH HARAJUKU B1, 1 Chome-14-30 Jingumae, Shibuya, Tokyo 150-0001, Japan",
            members: [.juni],
            routeType: .separate
        ),
        RoutePlace(
            id: 3,
            name: "도쿄 레코드숍",
            description: "다양한 음악을 만날 수 있는 곳",
            address: "1 Chome-14-30 Jingumae, Shibuya, Tokyo 150-0001, Japan",
            members: [.tae, .juni],
            routeType: .separate
        )
    ]
}
