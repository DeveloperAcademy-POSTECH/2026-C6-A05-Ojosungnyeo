//
//  PlaceGroupingPreviewData.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

enum PlaceGroupingPreviewData {
    static let tripTitle = "오사카 여행"
    static let tripDates = "11월 22일 ~ 25일"
    static let travelCriteria = "대중교통 · 장소 간 최대 30분"

    static let members: [PlaceGroupingFeature.Member] = [
        .init(id: "tae", name: "테이", preferences: "쇼핑, 맛집", avatar: .tae),
        .init(id: "header", name: "헤더", preferences: "서점, 디저트", avatar: .header),
        .init(id: "juni", name: "주니", preferences: "자연, 맛집", avatar: .juni),
        .init(id: "grae", name: "그레", preferences: "자연, 게임", avatar: .grae),
    ]

    static let recommendedGroups: [PlaceGroupingFeature.RecommendedGroup] = [
        .init(id: "osaka-region-1", title: "오사카 지역 1", participantSummary: "2명 · 1명", memberIDs: ["tae", "header"], categories: ["쇼핑", "디저트"], places: []),
        .init(id: "osaka-region-2", title: "오사카 지역 2", participantSummary: "4명", memberIDs: ["tae", "header", "juni", "grae"], categories: ["맛집"], places: []),
    ]

    static let placeGroups: [MapPlaceGroup] = [
        .init(
            id: "osaka-region-1",
            name: "오사카 지역 1",
            places: [
                .init(id: "osaka-castle", name: "오사카성", description: "", thumbnailName: "", latitude: 34.6873, longitude: 135.5262),
                .init(id: "osaka-museum", name: "오사카 역사박물관", description: "", thumbnailName: "", latitude: 34.6826, longitude: 135.5200),
                .init(id: "nakanoshima-park", name: "나카노시마 공원", description: "", thumbnailName: "", latitude: 34.6923, longitude: 135.5075),
            ],
            radius: 1_550
        ),
        .init(
            id: "osaka-region-2",
            name: "오사카 지역 2",
            places: [
                .init(id: "dotonbori", name: "도톤보리", description: "", thumbnailName: "", latitude: 34.6687, longitude: 135.5013),
                .init(id: "kuromon-market", name: "구로몬 시장", description: "", thumbnailName: "", latitude: 34.6654, longitude: 135.5067),
                .init(id: "shinsaibashi", name: "신사이바시", description: "", thumbnailName: "", latitude: 34.6747, longitude: 135.5010),
                .init(id: "namba-yasaka", name: "난바 야사카 신사", description: "", thumbnailName: "", latitude: 34.6616, longitude: 135.4966),
            ],
            radius: 2_050
        ),
    ]
}
