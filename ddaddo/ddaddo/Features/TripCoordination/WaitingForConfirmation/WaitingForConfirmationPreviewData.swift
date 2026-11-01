//
//  WaitingForConfirmationPreviewData.swift
//  ddaddo
//
//  Created by sun on 11/1/26.
//

enum WaitingForConfirmationPreviewData {
    static let tripTitle = "도쿄 여행"
    static let tripDates = "11월 22일 ~ 25일"

    static let members: [WaitingForConfirmationFeature.Member] = [
        .init(id: "tae", name: "테이", avatar: .tae, isConfirmed: true),
        .init(id: "header", name: "헤더", avatar: .header, isConfirmed: true),
        .init(id: "juni", name: "주니", avatar: .juni, isConfirmed: false),
        .init(id: "grae", name: "그레", avatar: .grae, isConfirmed: false),
    ]
}
