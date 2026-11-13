import SwiftUI

extension View {
    /// A bar inset into the safe area at `edge`, such as the Search tab's filter chips above
    /// its search field. iOS 26 uses `safeAreaBar`, so the scroll edge effect fades content
    /// scrolling under the bar as it does under the system bars; iOS 18 uses `safeAreaInset`.
    func floatingBar(
        edge: VerticalEdge, spacing: CGFloat? = nil, @ViewBuilder content: () -> some View
    ) -> some View {
        modifier(FloatingBar(edge: edge, spacing: spacing, bar: content()))
    }
}

private struct FloatingBar<Bar: View>: ViewModifier {
    let edge: VerticalEdge
    let spacing: CGFloat?
    let bar: Bar

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: edge, spacing: spacing) { bar }
        } else {
            content.safeAreaInset(edge: edge, spacing: spacing) { bar }
        }
    }
}
