import SwiftUI

extension View {
    /// Hides the soft edge effect iOS 26 draws under the navigation bar while `isHidden`, for a
    /// scroll view whose content is meant to show under the bar at rest, such as the detail
    /// page's cover rising between the bar's buttons (E-Detail). Without this the top of the
    /// cover is blurred before anything has scrolled.
    ///
    /// Nothing on iOS 18, whose bar is clear at the top of the page and draws its own
    /// background once the content scrolls under it.
    func hidesTopScrollEdgeEffect(_ isHidden: Bool = true) -> some View {
        modifier(TopScrollEdgeEffectHidden(isHidden: isHidden))
    }
}

private struct TopScrollEdgeEffectHidden: ViewModifier {
    let isHidden: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectHidden(isHidden, for: .top)
        } else {
            content
        }
    }
}
