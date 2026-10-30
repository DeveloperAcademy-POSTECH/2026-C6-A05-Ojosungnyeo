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
        var visibleMembers = Set(TripMember.allCases)
        var selectedPlaceID: RoutePlace.ID? = RoutePlace.mockPlaces[1].id
        let places = RoutePlace.mockPlaces

        var visibleStops: [RouteStop] {
            RouteStop.stopsByDay[selectedDay, default: []].filter { stop in
                !stop.members.isDisjoint(with: visibleMembers)
            }
        }

        var selectedPlace: RoutePlace {
            places.first { $0.id == selectedPlaceID } ?? places[0]
        }
    }

    enum Action: Equatable {
        case backButtonTapped
        case daySelected(TripDay)
        case memberTapped(TripMember)
        case editButtonTapped
        case placeChanged(RoutePlace.ID?)
        case addressCopyButtonTapped(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                return .none

            case let .daySelected(day):
                state.selectedDay = day
                return .none

            case let .memberTapped(member):
                if state.visibleMembers.contains(member) {
                    state.visibleMembers.remove(member)
                } else {
                    state.visibleMembers.insert(member)
                }
                return .none

            case .editButtonTapped:
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

struct RouteStop: Equatable, Identifiable {
    let id: Int
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double
    let members: Set<TripMember>

    static let stopsByDay: [TripDay: [RouteStop]] = [
        .day1: [
            RouteStop(id: 0, name: "도쿄역 근처 쇼핑", category: "쇼핑", latitude: 35.6812, longitude: 139.7671, members: Set(TripMember.allCases)),
            RouteStop(id: 1, name: "도쿄역", category: "관광", latitude: 35.6896, longitude: 139.7006, members: [.header, .grae]),
            RouteStop(id: 2, name: "도쿄 국립박물관", category: "문화", latitude: 35.7188, longitude: 139.7765, members: Set(TripMember.allCases)),
            RouteStop(id: 3, name: "아사쿠사", category: "관광", latitude: 35.7148, longitude: 139.7967, members: [.tae, .juni])
        ],
        .day2: [
            RouteStop(id: 10, name: "메이지 신궁", category: "관광", latitude: 35.6764, longitude: 139.6993, members: Set(TripMember.allCases)),
            RouteStop(id: 11, name: "하라주쿠", category: "쇼핑", latitude: 35.6702, longitude: 139.7027, members: [.tae, .header]),
            RouteStop(id: 12, name: "시부야 스카이", category: "전망", latitude: 35.6585, longitude: 139.7013, members: Set(TripMember.allCases))
        ],
        .day3: [
            RouteStop(id: 20, name: "도쿄 타워", category: "관광", latitude: 35.6586, longitude: 139.7454, members: Set(TripMember.allCases)),
            RouteStop(id: 21, name: "긴자", category: "쇼핑", latitude: 35.6717, longitude: 139.7650, members: [.grae, .juni]),
            RouteStop(id: 22, name: "오다이바", category: "관광", latitude: 35.6272, longitude: 139.7768, members: Set(TripMember.allCases))
        ],
        .day4: [
            RouteStop(id: 30, name: "우에노 공원", category: "산책", latitude: 35.7148, longitude: 139.7732, members: Set(TripMember.allCases)),
            RouteStop(id: 31, name: "아키하바라", category: "쇼핑", latitude: 35.6984, longitude: 139.7731, members: Set(TripMember.allCases)),
            RouteStop(id: 32, name: "도쿄역", category: "이동", latitude: 35.6812, longitude: 139.7671, members: Set(TripMember.allCases))
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
