//
//  DDMiniHeadAvatar.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct DDMiniHeadAvatar: View {
    typealias Character = ParticipantAvatar

    let character: Character
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(character.backgroundColor)

            Image(character.rawValue)
                .resizable()
                .scaledToFit()
                .frame(
                    width: size * character.faceWidthRatio,
                    height: size * character.faceHeightRatio
                )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension ParticipantAvatar {
    fileprivate var faceWidthRatio: CGFloat {
        switch self {
        case .tae, .header:
            51 / 56
        case .grae:
            47.778 / 56
        case .juni:
            48 / 56
        }
    }

    fileprivate var faceHeightRatio: CGFloat {
        switch self {
        case .tae:
            45 / 56
        case .header:
            42 / 56
        case .grae:
            40.273 / 56
        case .juni:
            36 / 56
        }
    }

    var backgroundColor: Color {
        switch self {
        case .grae:
            Color(red: 102 / 255, green: 181 / 255, blue: 173 / 255)
        case .header:
            Color(red: 152 / 255, green: 156 / 255, blue: 209 / 255)
        case .juni:
            Color(red: 197 / 255, green: 143 / 255, blue: 167 / 255)
        case .tae:
            Color(red: 217 / 255, green: 149 / 255, blue: 126 / 255)
        }
    }
}
