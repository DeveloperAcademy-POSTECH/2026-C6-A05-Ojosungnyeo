//
//  DDMiniHeadAvatar.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct DDMiniHeadAvatar: View {
    enum Character: String {
        case tae = "DDMiniHeadTae"
        case header = "DDMiniHeadHeader"
        case grae = "DDMiniHeadGrae"
        case juni = "DDMiniHeadJuni"
    }

    let character: Character
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 48.0 / 255.0, green: 48.0 / 255.0, blue: 48.0 / 255.0))

            Image(character.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.86, height: size * 0.74)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
