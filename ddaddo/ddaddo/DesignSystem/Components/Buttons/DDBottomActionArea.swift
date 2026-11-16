//
//  DDBottomActionArea.swift
//  ddaddo
//

import SwiftUI

/// 하단 큰 실행 버튼의 좌우 여백과 안전 영역 위 간격을 통일한다.
struct DDBottomActionArea<Content: View>: View {
    private let topSpacing: CGFloat
    private let bottomSafeAreaInset: CGFloat
    private let backgroundColor: Color
    private let content: Content

    init(
        topSpacing: CGFloat = DDSpacing.large,
        bottomSafeAreaInset: CGFloat = 0,
        backgroundColor: Color = DDColor.surfaceDefault,
        @ViewBuilder content: () -> Content
    ) {
        self.topSpacing = topSpacing
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, DDBottomActionLayout.horizontalInset)
        .padding(.top, topSpacing)
        .padding(.bottom, DDBottomActionLayout.bottomPadding(safeAreaInset: bottomSafeAreaInset))
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
    }
}
