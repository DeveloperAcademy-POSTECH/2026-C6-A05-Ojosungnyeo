//
//  UpcomingTripsPreviewData.swift
//  ddaddo
//

// 목업 데이터. 추후 서버 연결 후 삭제 가능
enum UpcomingTripsPreviewData {
    static let state = UpcomingTripsFeature.State(
        trips: [
            .init(
                id: "tokyo",
                destination: "일본 도쿄",
                dateText: "2026년 11월 22일 ~ 29일",
                participantCount: 4,
                imageName: "DDUpcomingTripCity"
            ),
            .init(
                id: "melbourne",
                destination: "호주 멜버른",
                dateText: "2027년 3월 7일 ~ 15일",
                participantCount: 3,
                imageName: "DDUpcomingTripCity"
            ),
            .init(
                id: "chongqing",
                destination: "중국 충칭",
                dateText: "2027년 4월 10일 ~ 17일",
                participantCount: 6,
                imageName: "DDUpcomingTripChongqing"
            )
        ]
    )
}
