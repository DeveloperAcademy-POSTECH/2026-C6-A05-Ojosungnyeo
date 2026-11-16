//
//  DDNavigationHeader.swift
//  ddaddo
//

import SwiftUI

/// 화면 왼쪽에 배치하며 제목은 44pt 터치 영역 바로 다음에서 시작한다.
struct DDNavigationHeader<Content: View>: View {
    private let accessibilityLabel: String
    private let alignment: VerticalAlignment
    private let height: CGFloat
    private let onBack: () -> Void
    private let content: Content

    init(
        accessibilityLabel: String = "뒤로",
        alignment: VerticalAlignment = .center,
        height: CGFloat = 44,
        onBack: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.alignment = alignment
        self.height = height
        self.onBack = onBack
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 0) {
            DDBackButton(
                accessibilityLabel: accessibilityLabel,
                action: onBack
            )
            content
        }
        .frame(height: height, alignment: .top)
    }
}
