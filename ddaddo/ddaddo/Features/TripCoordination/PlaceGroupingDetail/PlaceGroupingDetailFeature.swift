//
//  PlaceGroupingDetailFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct PlaceGroupingDetailFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var tripTitle = "도쿄 여행"
        var tripDates = "11월 22일 ~ 25일"
        var groupTitle = "도쿄 쇼핑을 즐기게따!"
        var members: [Member] = Member.preview
        var places: [Place] = Place.preview
    }

    struct Member: Equatable, Identifiable {
        let id: String
        let character: DDMiniHeadAvatar.Character

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id && lhs.character.rawValue == rhs.character.rawValue
        }
    }

    struct Place: Equatable, Identifiable {
        let id: String
        let title: String
        let address: String
        let imageName: String
    }

    enum Action {
        case backButtonTapped
        case menuButtonTapped
        case editPlaceTapped(String)
        case deletePlaceTapped(String)
        case nextButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { _, _ in
            .none
        }
    }
}

extension PlaceGroupingDetailFeature.Member {
    fileprivate static let preview: [Self] = [
        .init(id: "tae", character: .tae),
        .init(id: "header", character: .header),
        .init(id: "juni", character: .juni),
        .init(id: "grae", character: .grae),
    ]
}

extension PlaceGroupingDetailFeature.Place {
    fileprivate static let preview: [Self] = [
        .init(
            id: "tokyo-station-shopping",
            title: "도쿄역 근처 쇼핑",
            address: "2 Chome-1004 Tokyo, Chuo\nWard, 福岡市 福岡県 810-0001",
            imageName: "DDPlaceTokyoStation"
        ),
        .init(
            id: "tokyo-market-street",
            title: "도쿄 시장 거리 구경",
            address: "89G2+WH, Tsushima, Nagasaki\n817-1105",
            imageName: "DDPlaceTokyoMarket"
        ),
        .init(
            id: "stussy-tokyo",
            title: "스투시 도쿄점",
            address: "89G2+WH, Tsushima, Nagasaki\n817-1105",
            imageName: "DDPlaceStussyTokyo"
        ),
        .init(
            id: "matcha-frappe-park",
            title: "더 말차 프라페 파크",
            address: "〒150-0001 Tokyo, Shibuya,\n6 Chome−20−10 South 2F",
            imageName: "DDPlaceMatchaPark"
        ),
    ]
}
