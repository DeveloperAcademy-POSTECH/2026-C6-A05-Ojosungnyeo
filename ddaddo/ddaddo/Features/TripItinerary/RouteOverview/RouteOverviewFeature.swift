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
        var selectedPlaceID: RoutePlace.ID? = RoutePlace.mockPlaces[1].id
        let places = RoutePlace.mockPlaces

        var selectedPlace: RoutePlace {
            places.first { $0.id == selectedPlaceID } ?? places[0]
        }
    }

    enum Action: Equatable {
        case backButtonTapped
        case placeChanged(RoutePlace.ID?)
        case addressCopyButtonTapped(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
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
