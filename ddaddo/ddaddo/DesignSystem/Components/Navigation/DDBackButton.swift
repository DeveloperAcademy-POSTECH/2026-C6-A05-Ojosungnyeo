//
//  DDBackButton.swift
//  ddaddo
//

import SwiftUI

struct DDBackButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    init(
        accessibilityLabel: String = "뒤로",
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image("DDBackChevron")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
