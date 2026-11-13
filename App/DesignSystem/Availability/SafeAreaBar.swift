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

extension View {
    /// A pushed screen's title with a top `floatingBar` pinned under it, for a screen whose bar
    /// swaps the list below (Toplists over its period chips).
    ///
    /// iOS 26 draws the title in the bar, large and never collapsing, above `content`, and
    /// removes the navigation bar's own: the bar's scroll edge effect reaches over the navigation
    /// bar's large title and blurs it, and a collapsing title is left half collapsed when the
    /// list that collapsed it is replaced. iOS 18 keeps v3's inline title, with the search
    /// field's drawer under it and the bar under that.
    func titledFloatingBar(
        _ title: String, background: FloatingBarBackground = .none, @ViewBuilder content: () -> some View
    ) -> some View {
        modifier(TitledFloatingBar(title: title, background: background, bar: content()))
    }
}

private struct TitledFloatingBar<Bar: View>: ViewModifier {
    let title: String
    let background: FloatingBarBackground
    let bar: Bar

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .floatingBar(edge: .top, spacing: 0, background: background) {
                    VStack(alignment: .leading, spacing: 0) {
                        BarTitle(title: title)
                        bar
                    }
                }
                .navigationTitle(title)
                .toolbarTitleDisplayMode(.inline)
                .toolbar(removing: .title)
        } else {
            content
                .floatingBar(edge: .top, spacing: 0, background: background) { bar }
                .navigationTitle(title)
                .toolbarTitleDisplayMode(.inline)
        }
    }
}

/// The large title as the navigation bar would draw it, on the bar's leading margin.
private struct BarTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.screenTitle)
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            // It stays on screen, so it stops growing where the navigation bar's title does.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.horizontal, Tokens.Spacing.large)
            .accessibilityAddTraits(.isHeader)
    }
}
