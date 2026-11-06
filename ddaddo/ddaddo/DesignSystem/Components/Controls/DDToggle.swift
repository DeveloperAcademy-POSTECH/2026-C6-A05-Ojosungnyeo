//
//  DDToggle.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

import SwiftUI

struct DDToggle: View {
    @Binding private var isOn: Bool
    private let accessibilityLabel: String

    init(isOn: Binding<Bool>, accessibilityLabel: String) {
        _isOn = isOn
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? DDColor.actionPrimary : DDColor.surfaceControl)

                Circle()
                    .fill(isOn ? DDColor.surfaceDefault : DDColor.textSecondary)
                    .frame(width: 22, height: 22)
                    .padding(2)
            }
            .frame(width: 42, height: 26)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "켬" : "끔")
        .accessibilityAddTraits(.isButton)
    }
}

