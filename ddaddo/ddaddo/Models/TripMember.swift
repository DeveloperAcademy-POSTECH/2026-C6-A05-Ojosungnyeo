//
//  TripMember.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

enum TripMember: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case tae
    case header
    case grae
    case juni

    var id: Self { self }

    init(avatar: ParticipantAvatar) {
        switch avatar {
        case .tae: self = .tae
        case .header: self = .header
        case .grae: self = .grae
        case .juni: self = .juni
        }
    }

    var avatar: ParticipantAvatar {
        switch self {
        case .tae: .tae
        case .header: .header
        case .grae: .grae
        case .juni: .juni
        }
    }
}
