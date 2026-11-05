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
