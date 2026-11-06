//
//  DDCTAButton.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct DDCTAButton: View {
    enum Style {
        case primary
        case secondary
    }

    enum Layout {
        case full
        case compact
    }

    let title: String
    var style: Style = .primary
    var layout: Layout = .full
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .ddTypography(layout == .full ? .heading20 : .bodyEmphasis16)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, layout == .full ? 0 : DDSpacing.large)
                .frame(maxWidth: layout == .full ? .infinity : nil)
                .frame(minHeight: layout == .full ? 55 : 44)
                .background(backgroundColor)
                .clipShape(.rect(cornerRadius: layout == .full ? DDRadius.medium : DDRadius.pill))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: DDColor.actionPrimary
        case .secondary: DDColor.actionSecondary
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: DDColor.textOnPrimary
        case .secondary: DDColor.textPrimary
        }
    }
}

#Preview {
    VStack(spacing: DDSpacing.small) {
        DDCTAButton(title: "바로 시작", action: {})
        DDCTAButton(title: "링크 공유", style: .secondary, action: {})
    }
    .padding(.horizontal, DDSpacing.xLarge)
    .padding(.vertical)
    .background(DDColor.surfaceDefault)
}
