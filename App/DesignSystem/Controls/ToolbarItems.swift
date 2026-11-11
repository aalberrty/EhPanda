import SwiftUI

// Legacy `CustomToolbarItem` wrapped several buttons in one `HStack` item. On iOS 26 that defeats
// the toolbar's own glass grouping, so it is not ported: use `ToolbarItemGroup` (and
// `ToolbarSpacer` to split groups), with `.tint` / `.disabled` on the items themselves.

/// The "more" menu at the trailing edge of a toolbar (legacy `ToolbarFeaturesMenu`).
struct ToolbarFeaturesMenu<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            // The symbol carries the system's localized "More" label for VoiceOver.
            Image(systemName: "ellipsis")
        }
    }
}

/// Opens the search filters (legacy `FiltersButton`). Inside a menu it shows its title too.
struct FiltersButton: View {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(L10n.Localizable.ToolbarItem.Button.filters, systemImage: "line.3.horizontal.decrease", action: action)
    }
}

/// Opens quick search (legacy `QuickSearchButton`).
struct QuickSearchButton: View {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(L10n.Localizable.ToolbarItem.Button.quickSearch, systemImage: "magnifyingglass", action: action)
    }
}

/// Opens the jump-to-page prompt (legacy `JumpPageButton`). Disable it for single-page results.
struct JumpPageButton: View {
    private let isDisabled: Bool
    private let action: () -> Void

    init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(L10n.Localizable.ToolbarItem.Button.jumpPage, systemImage: "arrowshape.bounce.forward", action: action)
            .disabled(isDisabled)
    }
}

/// A toolbar menu that picks one value with a checkmark, replacing legacy `FavoritesIndexMenu`,
/// `ToplistsTypeMenu` and `SortOrderMenu`, which differed only in their model type.
///
/// `selection` may be `nil` when nothing is chosen yet (legacy favourites sort order).
struct ToolbarPickerMenu<Value: Hashable>: View {
    private let title: String
    private let systemImage: String
    private let options: [Value]
    private let selection: Value?
    private let optionTitle: (Value) -> String
    private let onSelect: (Value) -> Void

    init(
        _ title: String, systemImage: String, options: [Value], selection: Value?,
        optionTitle: @escaping (Value) -> String, onSelect: @escaping (Value) -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.options = options
        self.selection = selection
        self.optionTitle = optionTitle
        self.onSelect = onSelect
    }

    var body: some View {
        Menu {
            Picker(title, selection: binding) {
                ForEach(options, id: \.self) { option in
                    Text(optionTitle(option)).tag(Optional(option))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(title, systemImage: systemImage)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var binding: Binding<Value?> {
        Binding(get: { selection }, set: { newValue in newValue.map(onSelect) })
    }
}

private struct ToolbarItemsPreview: View {
    @State private var sortOrder: String?
    @State private var favoritesIndex = -1

    var body: some View {
        NavigationStack {
            List {
                Text(verbatim: "sort: \(sortOrder ?? "none"), index: \(favoritesIndex)")
            }
            .navigationTitle(L10n.Localizable.TabItem.Title.favorites)
            .toolbar {
                ToolbarItemGroup {
                    ToolbarPickerMenu(
                        "Favorites", systemImage: "dial.low", options: Array(-1..<10), selection: favoritesIndex,
                        optionTitle: { $0 == -1 ? "All" : "Favorites \($0)" }, onSelect: { favoritesIndex = $0 }
                    )
                    ToolbarPickerMenu(
                        "Sort", systemImage: "arrow.up.arrow.down.circle", options: ["Favorited", "Updated"],
                        selection: sortOrder, optionTitle: { $0 }, onSelect: { sortOrder = $0 }
                    )
                }
                ToolbarSpacer(.fixed)
                ToolbarItem {
                    ToolbarFeaturesMenu {
                        FiltersButton {}
                        QuickSearchButton {}
                        JumpPageButton(isDisabled: true) {}
                    }
                }
            }
        }
    }
}

#Preview {
    ToolbarItemsPreview()
}

#Preview("Dark") {
    ToolbarItemsPreview().preferredColorScheme(.dark)
}
