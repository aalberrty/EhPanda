import SwiftUI

// The one place the Library picks `safeAreaBar` (iOS 26) or its iOS 18 stand-in. It belongs with
// the other fallbacks in `App/DesignSystem/Availability` and moves there once the design
// foundation work has landed.

extension View {
    /// Pins `content` to the top of the view, under the navigation bar, with the lists scrolling
    /// beneath it: a `safeAreaBar` on iOS 26, so the system's scroll edge effect covers it; on
    /// iOS 18 a safe-area inset on the bar material.
    ///
    /// `extendsBehindTopBar` lets the iOS 18 material run up behind the navigation bar, which then
    /// draws no background of its own, so the title and the bar read as one surface. Pass `false`
    /// for a second bar stacked under the first.
    func libraryBar(extendsBehindTopBar: Bool = true, @ViewBuilder content: () -> some View) -> some View {
        modifier(LibraryBar(extendsBehindTopBar: extendsBehindTopBar, bar: content()))
    }
}

private struct LibraryBar<Bar: View>: ViewModifier {
    let extendsBehindTopBar: Bool
    let bar: Bar

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) { bar }
        } else if extendsBehindTopBar {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    bar.background(.bar, ignoresSafeAreaEdges: .top)
                }
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                bar.background(.bar, ignoresSafeAreaEdges: [])
            }
        }
    }
}
