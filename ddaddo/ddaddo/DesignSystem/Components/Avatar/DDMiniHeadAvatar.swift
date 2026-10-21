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
        case grae = "DDMiniHeadGrace"
        case juni = "DDMiniHeadJuni"
    }

    let character: Character
    var size: CGFloat = 56

    var body: some View {
        Image(character.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.circle)
            .accessibilityHidden(true)
    }
}
