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
/// legacy folder menu).
struct FavoriteFolderChips: View {
    let model: FavoritesModel

    var body: some View {
        ChipRow(
            L10n.Localizable.FavoritesView.Title.favorites, options: model.folders,
            selection: model.category, optionTitle: { title(of: $0) },
            onSelect: { model.select(category: $0.index) }
        )
    }

    private func title(of folder: FavoriteFolder) -> String {
        if folder.isAll { return L10n.Localizable.Struct.User.FavoriteCategory.all }
        return folder.customName ?? L10n.Localizable.Struct.User.FavoriteCategory.default("\(folder.index)")
    }
}
