//
//  ParticipantAvatar.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import Foundation

enum ParticipantAvatar: String, CaseIterable, Equatable, Sendable {
    case grae = "DDMiniHeadGrae"
    case header = "DDMiniHeadHeader"
    case juni = "DDMiniHeadJuni"
    case tae = "DDMiniHeadTae"

    private static let rotation: [Self] = [.grae, .header, .juni, .tae]

    static func matched(to name: String) -> Self? {
        let normalizedName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedName.contains("그레") || normalizedName.contains("grae") {
            return .grae
        }
        if normalizedName.contains("헤더") || normalizedName.contains("header") {
            return .header
        }
        if normalizedName.contains("주니") || normalizedName.contains("juni") {
            return .juni
        }
        if normalizedName.contains("테이") || normalizedName.contains("tae") {
            return .tae
        }

        return nil
    }

    static func assigned(to name: String, fallbackIndex: Int) -> Self {
        matched(to: name) ?? rotation[fallbackIndex % rotation.count]
    }
}
