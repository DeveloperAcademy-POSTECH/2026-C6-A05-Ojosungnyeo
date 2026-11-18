import SwiftUI

private struct DDBottomSheetBottomFillModifier: ViewModifier {
    let color: Color
    let extensionHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .background(alignment: .bottom) {
                color
                    .frame(maxWidth: .infinity)
                    .frame(height: extensionHeight)
                    .offset(y: extensionHeight)
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}

extension View {
    /// Draws the same inset border on every sheet, without a horizontal line at its bottom.
    func ddBottomSheetBorder(cornerRadius: CGFloat = 40) -> some View {
        overlay {
            GeometryReader { geometry in
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    topTrailingRadius: cornerRadius
                )
                .strokeBorder(DDColor.borderSubtle, lineWidth: 1)
                .frame(height: geometry.size.height + 120)
            }
            .allowsHitTesting(false)
        }
    }

    /// Keeps a custom bottom sheet visually attached to the physical bottom edge.
    /// The sheet's content height stays unchanged while only its background extends downward.
    func ddFillBottomSheetToScreenEdge(
        color: Color = DDColor.surfaceDefault,
        extensionHeight: CGFloat = 120
    ) -> some View {
        modifier(
            DDBottomSheetBottomFillModifier(
                color: color,
                extensionHeight: extensionHeight
            )
        )
    }
}
