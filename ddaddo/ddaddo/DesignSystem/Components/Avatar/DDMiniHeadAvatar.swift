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
                .frame(width: size * 0.86, height: size * 0.74)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension ParticipantAvatar {
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
