import EhFeatures
import SwiftUI

/// Favorites, Watched and History: the three-part control under the Library title.
struct LibrarySegmentPicker: View {
    let model: LibraryModel

    var body: some View {
        SegmentedControl(
            L10n.Localizable.TabItem.Title.library, options: LibrarySegment.allCases,
            selection: model.segment, optionTitle: \.localizedName, onSelect: { model.select($0) }
        )
        .padding(.horizontal, Tokens.Spacing.large)
        .padding(.vertical, Tokens.Spacing.small)
    }
}

/// "All", then each favourites folder by the user's own name or "Favorites N" (replacing the
/// legacy folder menu). The selected chip scrolls into view.
struct FavoriteFolderChips: View {
    let model: FavoritesModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Tokens.Spacing.small) {
                    ForEach(model.folders) { folder in
                        FolderChip(title: title(of: folder), isSelected: folder.index == model.category) {
                            model.select(category: folder.index)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.large)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.category, initial: true) { old, category in
                guard category != old else {
                    // Appearing (after logging in, say): no animation.
                    proxy.scrollTo(category, anchor: .center)
                    return
                }
                withAnimation { proxy.scrollTo(category, anchor: .center) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Localizable.FavoritesView.Title.favorites)
    }

    private func title(of folder: FavoriteFolder) -> String {
        if folder.isAll { return L10n.Localizable.Struct.User.FavoriteCategory.all }
        return folder.customName ?? L10n.Localizable.Struct.User.FavoriteCategory.default("\(folder.index)")
    }
}

/// A folder chip: a filled capsule in a full-height touch target, inverted when selected.
///
/// The fills are colours rather than hierarchical styles: on the iOS 18 bar material
/// `.primary` and `.fill` turn into vibrant greys, and the selected chip would lose its contrast.
private struct FolderChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.onSelectedFill : Color.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .background(isSelected ? Color.selectedFill : Color.chipFill, in: .capsule)
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
