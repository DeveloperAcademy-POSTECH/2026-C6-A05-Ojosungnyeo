//
//  ParticipantAvatar.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import Foundation

enum ParticipantAvatar: String, CaseIterable, Equatable, Hashable, Sendable {
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

    static func uniqueAssignments(count: Int, first: Self) -> [Self] {
        guard count > 0 else { return [] }

        let remaining = rotation
            .filter { $0 != first }
            .shuffled()
        let uniqueAssignments = [first] + remaining

        guard count > uniqueAssignments.count else {
            return Array(uniqueAssignments.prefix(count))
        }

        return (0..<count).map { uniqueAssignments[$0 % uniqueAssignments.count] }
    }

    static func availableAssignment(
        preferred: Self?,
        excluding usedAvatars: Set<Self>
    ) -> Self {
        if let preferred, !usedAvatars.contains(preferred) {
            return preferred
        }

        return rotation
            .filter { !usedAvatars.contains($0) }
            .randomElement()
            ?? preferred
            ?? rotation.randomElement()!
    }
}
