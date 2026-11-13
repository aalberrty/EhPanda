import SwiftUI

// A search field that waits in the toolbar until it is wanted: on iOS 26 a search button among
// the toolbar's own items that expands into the field (`searchToolbarBehavior(.minimize)`); on
// iOS 18, which has neither, the field in the navigation bar drawer as before.

extension View {
    /// Searches `text`; put `ToolbarSearchItem` in the toolbar where the button belongs.
    func toolbarSearchable(text: Binding<String>, prompt: String) -> some View {
        modifier(ToolbarSearchable(text: text, prompt: prompt))
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

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .searchable(text: $text, placement: .toolbar, prompt: prompt)
                .searchToolbarBehavior(.minimize)
        } else {
            content.searchable(text: $text, prompt: prompt)
        }
    }
}
