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

    /// 기존 Dev 일정에 저장된 아바타 이름도 현재 멤버 ID로 읽는다.
    nonisolated init?(storedID: String) {
        if let member = Self(rawValue: storedID) {
            self = member
        } else if let avatar = ParticipantAvatar(rawValue: storedID) {
            self.init(avatar: avatar)
        } else {
            return nil
        }
    }

    nonisolated init(avatar: ParticipantAvatar) {
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
