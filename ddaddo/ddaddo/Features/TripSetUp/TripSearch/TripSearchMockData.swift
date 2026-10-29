//
//  TripSearchMockData.swift
//  ddaddo
//

enum TripSearchMockData {
    static let cities: [TripSearchFeature.City] =
        cities(country: "일본", region: .asia, flag: "DDTripSearchJapanFlag", entries: [
            ("tokyo", "도쿄"), ("osaka", "오사카"), ("kyoto", "교토"),
            ("fukuoka", "후쿠오카"), ("sapporo", "삿포로"), ("okinawa", "오키나와"),
            ("nagoya", "나고야"), ("kobe", "고베"), ("nara", "나라"),
            ("takamatsu", "다카마쓰"), ("yokohama", "요코하마"),
            ("kanazawa", "가나자와"), ("hiroshima", "히로시마")
        ])
        + cities(country: "대만", region: .asia, flag: "DDTripSearchFlagTW", entries: [
            ("taipei", "타이베이"), ("taichung", "타이중"),
            ("kaohsiung", "가오슝"), ("tainan", "타이난")
        ])
        + cities(country: "중국", region: .asia, flag: "DDTripSearchFlagCN", entries: [
            ("shanghai", "상하이"), ("beijing", "베이징"),
            ("qingdao", "칭다오"), ("chengdu", "청두")
        ])
        + cities(country: "홍콩", region: .asia, flag: "DDTripSearchFlagHK", entries: [
            ("hong-kong", "홍콩")
        ])
        + cities(country: "마카오", region: .asia, flag: "DDTripSearchFlagMO", entries: [
            ("macau", "마카오")
        ])
        + cities(country: "몽골", region: .asia, flag: "DDTripSearchFlagMN", entries: [
            ("ulaanbaatar", "울란바토르")
        ])
        + cities(country: "베트남", region: .southeastAsia, flag: "DDTripSearchFlagVN", entries: [
            ("danang", "다낭"), ("nha-trang", "나트랑"), ("hanoi", "하노이"),
            ("ho-chi-minh", "호찌민"), ("phu-quoc", "푸꾸옥"), ("hoi-an", "호이안")
        ])
        + cities(country: "태국", region: .southeastAsia, flag: "DDTripSearchFlagTH", entries: [
            ("bangkok", "방콕"), ("chiang-mai", "치앙마이"),
            ("phuket", "푸껫"), ("pattaya", "파타야")
        ])
        + cities(country: "인도네시아", region: .southeastAsia, flag: "DDTripSearchFlagID", entries: [
            ("bali", "발리")
        ])
        + cities(country: "필리핀", region: .southeastAsia, flag: "DDTripSearchFlagPH", entries: [
            ("cebu", "세부"), ("manila", "마닐라"), ("boracay", "보라카이")
        ])
        + cities(country: "싱가포르", region: .southeastAsia, flag: "DDTripSearchFlagSG", entries: [
            ("singapore", "싱가포르")
        ])
        + cities(country: "말레이시아", region: .southeastAsia, flag: "DDTripSearchFlagMY", entries: [
            ("kuala-lumpur", "쿠알라룸푸르")
        ])
        + cities(country: "프랑스", region: .europe, flag: "DDTripSearchFlagFR", entries: [
            ("paris", "파리")
        ])
        + cities(country: "영국", region: .europe, flag: "DDTripSearchFlagGB", entries: [
            ("london", "런던")
        ])
        + cities(country: "이탈리아", region: .europe, flag: "DDTripSearchFlagIT", entries: [
            ("rome", "로마"), ("florence", "피렌체"),
            ("venice", "베네치아"), ("milan", "밀라노")
        ])
        + cities(country: "스페인", region: .europe, flag: "DDTripSearchFlagES", entries: [
            ("barcelona", "바르셀로나"), ("madrid", "마드리드")
        ])
        + cities(country: "스위스", region: .europe, flag: "DDTripSearchFlagCH", entries: [
            ("zurich", "취리히"), ("interlaken", "인터라켄")
        ])
        + cities(country: "체코", region: .europe, flag: "DDTripSearchFlagCZ", entries: [
            ("prague", "프라하")
        ])
        + cities(country: "오스트리아", region: .europe, flag: "DDTripSearchFlagAT", entries: [
            ("vienna", "빈")
        ])
        + cities(country: "미국", region: .americasAndOceania, flag: "DDTripSearchFlagUS", entries: [
            ("new-york", "뉴욕"), ("los-angeles", "로스앤젤레스"),
            ("san-francisco", "샌프란시스코"), ("las-vegas", "라스베이거스"),
            ("seattle", "시애틀"), ("chicago", "시카고"), ("boston", "보스턴"),
            ("washington-dc", "워싱턴 D.C."), ("san-diego", "샌디에이고"),
            ("honolulu", "호놀룰루")
        ])
        + cities(country: "캐나다", region: .americasAndOceania, flag: "DDTripSearchFlagCA", entries: [
            ("vancouver", "밴쿠버"), ("toronto", "토론토")
        ])
        + cities(country: "호주", region: .americasAndOceania, flag: "DDTripSearchFlagAU", entries: [
            ("sydney", "시드니"), ("melbourne", "멜버른")
        ])
        + cities(country: "뉴질랜드", region: .americasAndOceania, flag: "DDTripSearchFlagNZ", entries: [
            ("auckland", "오클랜드")
        ])

    private static func cities(
        country: String,
        region: TripSearchFeature.Region,
        flag: String,
        entries: [(id: String, name: String)]
    ) -> [TripSearchFeature.City] {
        entries.map { entry in
            .init(
                id: entry.id,
                country: country,
                name: entry.name,
                region: region,
                thumbnailName: flag
            )
        }
    }
}
