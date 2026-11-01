//
//  PlaceGroupingPreviewData.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

enum PlaceGroupingPreviewData {
    static let tripTitle = "도쿄 여행"
    static let tripDates = "11월 22일 ~ 25일"
    static let travelCriteria = "대중교통 · 장소 간 최대 30분"

    static let members: [PlaceGroupingFeature.Member] = [
        .init(id: "tae", name: "테이", preferences: "쇼핑, 맛집", avatar: .tae),
        .init(id: "header", name: "헤더", preferences: "서점, 디저트", avatar: .header),
        .init(id: "juni", name: "주니", preferences: "자연, 맛집", avatar: .juni),
        .init(id: "grae", name: "그레", preferences: "자연, 게임", avatar: .grae),
    ]

    static let recommendedGroups: [PlaceGroupingFeature.RecommendedGroup] = [
        .init(id: "shinjuku", title: "신주쿠", participantSummary: "2명 · 1명"),
        .init(id: "chuo", title: "주오", participantSummary: "4명"),
    ]

    static let placeGroups: [MapPlaceGroup] = [
        .init(
            id: "shinjuku",
            name: "신주쿠",
            places: [
                .init(id: "shinjuku-gyoen", name: "신주쿠 교엔", description: "", thumbnailName: "", latitude: 35.6852, longitude: 139.7100),
                .init(id: "omoide-yokocho", name: "오모이데 요코초", description: "", thumbnailName: "", latitude: 35.6939, longitude: 139.6995),
                .init(id: "tokyo-metropolitan", name: "도쿄 도청 전망대", description: "", thumbnailName: "", latitude: 35.6896, longitude: 139.6917),
            ],
            radius: 1_550
        ),
        .init(
            id: "chuo",
            name: "주오",
            places: [
                .init(id: "ginza-six", name: "긴자 식스", description: "", thumbnailName: "", latitude: 35.6697, longitude: 139.7649),
                .init(id: "tsukiji-market", name: "쓰키지 장외시장", description: "", thumbnailName: "", latitude: 35.6655, longitude: 139.7707),
                .init(id: "tokyo-station", name: "도쿄역", description: "", thumbnailName: "", latitude: 35.6812, longitude: 139.7671),
                .init(id: "hamarikyu-gardens", name: "하마리큐 은사정원", description: "", thumbnailName: "", latitude: 35.6597, longitude: 139.7635),
            ],
            radius: 2_050
        ),
    ]
}
