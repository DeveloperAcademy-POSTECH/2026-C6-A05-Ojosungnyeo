//
//  UpcomingTripsPreviewData.swift
//  ddaddo
//

// 목업 데이터. 추후 서버 연결 후 삭제 가능
enum UpcomingTripsPreviewData {
    static let trips: [UpcomingTripsFeature.Trip] = [
            .init(
                id: "tokyo",
                destination: "TOKYO",
                country: "Japan",
                dateText: "11월 22일~25일"
            ),
            .init(
                id: "shanghai",
                destination: "SHANGHAI",
                country: "China",
                dateText: "12월 5일~8일"
            ),
            .init(
                id: "sydney",
                destination: "SYDNEY",
                country: "Australia",
                dateText: "27년 3월 2일~9일"
            )
        ]

    static let state = UpcomingTripsFeature.State(trips: trips)
}
