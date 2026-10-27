//
//  TripSetUpAccommodationMockData.swift
//  ddaddo
//

enum TripSetUpAccommodationMockData {
    static let accommodations: [TripSetUpAddAccommodationFeature.Accommodation] = [
        .init(
            id: "tokyo-dome-hotel",
            name: "도쿄돔 호텔",
            address: "1-3-61 고라쿠, 분쿄구, 도쿄",
            website: "https://www.tokyodome-hotels.com",
            latitude: 35.70364,
            longitude: 139.75347,
            thumbnailImageName: "DDMockAccommodationThumbnail",
            heroImageName: "DDMockAccommodationHero"
        ),
        .init(
            id: "richmond-suidobashi",
            name: "리치몬드 호텔 도쿄 스이도바시",
            address: "1-33-9 혼고, 분쿄구, 도쿄",
            website: "https://richmondhotel.jp/suidobashi/",
            latitude: 35.706153,
            longitude: 139.754940,
            thumbnailImageName: "DDMockAccommodationThumbnail",
            heroImageName: "DDMockAccommodationHero"
        ),
        .init(
            id: "metropolitan-edmont",
            name: "호텔 메트로폴리탄 에드몬트",
            address: "3-10-8 이이다바시, 치요다구, 도쿄",
            website: "https://edmont.metropolitan.jp/",
            latitude: 35.7008278,
            longitude: 139.7492667,
            thumbnailImageName: "DDMockAccommodationThumbnail",
            heroImageName: "DDMockAccommodationHero"
        ),
        .init(
            id: "hotel-niwa-tokyo",
            name: "호텔 니와 도쿄",
            address: "1-1-16 간다미사키초, 치요다구, 도쿄",
            website: "https://www.hotelniwa.jp/",
            latitude: 35.70051,
            longitude: 139.75682,
            thumbnailImageName: "DDMockAccommodationThumbnail",
            heroImageName: "DDMockAccommodationHero"
        )
    ]
}
