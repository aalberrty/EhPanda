import SwiftUI

// A hero image that rises into the navigation bar, between the bar's buttons (E-Detail's cover).
// iOS 26 draws the bar's buttons as glass circles, so the hero fits between them; iOS 18 keeps
// the hero below the bar, whose back button carries the previous screen's title and would run
// over it.

extension View {
    /// Raises the view by `distance` into the navigation bar on iOS 26; nothing on iOS 18.
    /// Apply it to the first view of the scroll content.
    func risesUnderNavigationBar(by distance: CGFloat) -> some View {
        padding(.top, AppLook.isRedesigned ? -distance : 0)
    }

    /// Hides the soft edge effect iOS 26 draws under the navigation bar while `isHidden`, for a
    /// scroll view whose content shows under the bar at rest (a hero raised with
    /// `risesUnderNavigationBar`). Without this the top of the hero is blurred before anything
    /// has scrolled.
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
