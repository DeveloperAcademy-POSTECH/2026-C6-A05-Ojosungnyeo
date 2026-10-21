//
//  DDTypography.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

enum DDTypography {
    case display64
    case display48
    case title28
    case title24
    case heading20
    case heading18
    case body16
    case bodyEmphasis16
    case label14
    case labelEmphasis14
    case caption12
    case captionEmphasis12

    fileprivate var fontName: String {
        switch self {
        case .heading20, .heading18, .bodyEmphasis16, .labelEmphasis14, .captionEmphasis12:
            "Pretendard-SemiBold"
        default:
            "Pretendard-Regular"
        }
    }

    fileprivate var size: CGFloat {
        switch self {
        case .display64: 64
        case .display48: 48
        case .title28: 28
        case .title24: 24
        case .heading20: 20
        case .heading18: 18
        case .body16, .bodyEmphasis16: 16
        case .label14, .labelEmphasis14: 14
        case .caption12, .captionEmphasis12: 12
        }
    }

    fileprivate var relativeTo: Font.TextStyle {
        switch self {
        case .display64, .display48: .largeTitle
        case .title28: .title
        case .title24: .title2
        case .heading20: .title3
        case .heading18: .headline
        case .body16, .bodyEmphasis16: .body
        case .label14, .labelEmphasis14: .subheadline
        case .caption12, .captionEmphasis12: .caption
        }
    }
}

private struct DDTypographyModifier: ViewModifier {
    let style: DDTypography

    func body(content: Content) -> some View {
        content.font(
            .custom(
                style.fontName,
                size: style.size,
                relativeTo: style.relativeTo
            )
        )
    }
}

extension View {
    func ddTypography(_ style: DDTypography) -> some View {
        modifier(DDTypographyModifier(style: style))
    }
}
