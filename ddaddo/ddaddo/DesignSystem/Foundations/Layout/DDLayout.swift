//
//  DDLayout.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import Foundation

enum DDSpacing {
    static let zero: CGFloat = 0
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let xxLarge: CGFloat = 32
}

enum DDRadius {
    static let zero: CGFloat = 0
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let pill: CGFloat = 999
}

enum DDBottomActionLayout {
    static let horizontalInset: CGFloat = DDSpacing.large
    static let bottomSpacing: CGFloat = 11

    /// 이미 안전 영역 안에 있는 화면은 0, 화면 끝까지 내려간 시트는 실제 인셋을 전달한다.
    static func bottomPadding(safeAreaInset: CGFloat = 0) -> CGFloat {
        max(0, safeAreaInset) + bottomSpacing
    }
}
