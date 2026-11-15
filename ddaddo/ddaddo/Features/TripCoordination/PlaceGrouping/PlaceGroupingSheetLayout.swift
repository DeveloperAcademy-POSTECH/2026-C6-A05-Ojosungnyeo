//
//  PlaceGroupingSheetLayout.swift
//  ddaddo
//

import Foundation

struct PlaceGroupingSheetLayout {
    enum Detent: CaseIterable {
        case collapsed
        case medium
        case expanded
    }

    let availableHeight: CGFloat
    let bottomSafeAreaInset: CGFloat

    var expandedHeight: CGFloat {
        max(0, availableHeight - 12)
    }

    var collapsedHeight: CGFloat {
        min(93 + bottomSafeAreaInset, expandedHeight)
    }

    func height(for detent: Detent) -> CGFloat {
        switch detent {
        case .collapsed:
            collapsedHeight
        case .medium:
            max(collapsedHeight, min(413, expandedHeight))
        case .expanded:
            expandedHeight
        }
    }

    func height(for detent: Detent, dragTranslation: CGFloat) -> CGFloat {
        min(expandedHeight, max(collapsedHeight, height(for: detent) - dragTranslation))
    }

    func nearestDetent(to projectedHeight: CGFloat) -> Detent {
        Detent.allCases.min {
            abs(height(for: $0) - projectedHeight) < abs(height(for: $1) - projectedHeight)
        } ?? .medium
    }
}
