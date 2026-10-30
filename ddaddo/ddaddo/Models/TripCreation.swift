//
//  TripCreation.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import Foundation

struct TripCreationRequest: Equatable, Sendable {
    let title: String
    let destinations: [TripDestination]
    let startDate: Date
    let endDate: Date
    let travelerCount: Int
    let transportation: String
    let maximumTravelMinutes: Int
}

struct TripInvitationSnapshot: Equatable, Sendable {
    struct Participant: Equatable, Identifiable, Sendable {
        let id: Int
        let name: String
        let avatarName: String?
        let hasJoined: Bool
    }

    let tripID: String
    let code: String
    let url: URL
    let expiresAt: Date
    let participants: [Participant]
}
