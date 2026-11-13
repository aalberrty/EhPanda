import SwiftUI

// A search field that waits in the toolbar until it is wanted: on iOS 26 a search button among
// the toolbar's own items that expands into the field (`searchToolbarBehavior(.minimize)`); on
// iOS 18, which has neither, the field in the navigation bar drawer as before.

extension View {
    /// Searches `text`; put `ToolbarSearchItem` in the toolbar where the button belongs.
    ///
    /// `alwaysShowsField` keeps the iOS 18 drawer's field on screen instead of revealing it when
    /// the list is pulled down. A screen whose top `floatingBar` holds a sideways scrolling row
    /// (Toplists' chips) needs it: iOS 18's navigation bar follows that row rather than the
    /// list, so pulling the list down only refreshes it. Nothing changes on iOS 26.
    func toolbarSearchable(text: Binding<String>, prompt: String, alwaysShowsField: Bool = false) -> some View {
        modifier(ToolbarSearchable(text: text, prompt: prompt, alwaysShowsField: alwaysShowsField))
    }
}

/// The place of `toolbarSearchable`'s button among the toolbar's items (iOS 26); nothing on
/// iOS 18, whose field stays in the navigation bar drawer.
struct ToolbarSearchItem: ToolbarContent {
    var placement: ToolbarItemPlacement = .primaryAction

    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            DefaultToolbarItem(kind: .search, placement: placement)
        }
    }
}

private struct ToolbarSearchable: ViewModifier {
    @Binding var text: String
    let prompt: String
    let alwaysShowsField: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .searchable(text: $text, placement: .toolbar, prompt: prompt)
                .searchToolbarBehavior(.minimize)
        } else if alwaysShowsField {
            content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
        } else {
            content.searchable(text: $text, prompt: prompt)
        }
    }
}
