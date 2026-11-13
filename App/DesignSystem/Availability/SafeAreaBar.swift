import SwiftUI

/// What iOS 18 draws behind a `floatingBar`, where no scroll edge effect covers the content
/// scrolling under the bar.
enum FloatingBarBackground {
    /// Nothing: the bar draws its own surface (the Search tab's chips on their capsule).
    case none
    /// The bar material, as far as the bar reaches: a second bar stacked under another.
    case material
    /// The bar material running up behind the navigation bar, which then draws no background
    /// of its own, so the title and the bar read as one surface (Library's segment control).
    /// For a bar at the top edge.
    case materialUnderNavigationBar
}

extension View {
    /// A bar inset into the safe area at `edge`, with the content scrolling under it: the Search
    /// tab's filter chips above its search field, Library's segment control under its title.
    ///
    /// iOS 26 uses `safeAreaBar`, so the scroll edge effect fades content under the bar as it
    /// does under the system bars; `background` is ignored. iOS 18 uses `safeAreaInset` with
    /// `background` behind the bar.
    func floatingBar(
        edge: VerticalEdge, spacing: CGFloat? = nil, background: FloatingBarBackground = .none,
        @ViewBuilder content: () -> some View
    ) -> some View {
        modifier(FloatingBar(edge: edge, spacing: spacing, background: background, bar: content()))
    }
}

private struct FloatingBar<Bar: View>: ViewModifier {
    let edge: VerticalEdge
    let spacing: CGFloat?
    let background: FloatingBarBackground
    let bar: Bar

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: edge, spacing: spacing) { bar }
        } else {
            switch background {
            case .none:
                content.safeAreaInset(edge: edge, spacing: spacing) { bar }
            case .material:
                content.safeAreaInset(edge: edge, spacing: spacing) {
                    bar.background(.bar, ignoresSafeAreaEdges: [])
                }
            case .materialUnderNavigationBar:
                content
                    .safeAreaInset(edge: edge, spacing: spacing) {
                        bar.background(.bar, ignoresSafeAreaEdges: .top)
                    }
                    .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            }
        }
    }
}
