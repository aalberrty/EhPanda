import EhFeatures
import EhModels
import SwiftUI

/// The display mode, which every segment shares and so stays in place, then the tools of the
/// segment on show: Quick search and the sort order for Favorites, Quick search and Filters for
/// Watched, Clear for History. The search field is the screen's own.
struct LibraryToolbar: ToolbarContent {
    let model: LibraryModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            ListDisplayModeButton()
            switch model.segment {
            case .favorites:
                QuickSearchButton { model.destination = .quickSearch }
                FavoritesSortMenu(model: model.favorites)
            case .watched:
                QuickSearchButton { model.destination = .quickSearch }
                FiltersButton { model.destination = .filters }
            case .history:
                HistoryClearButton(model: model.history)
            }
        }
    }
}

private struct FavoritesSortMenu: View {
    let model: FavoritesModel

    var body: some View {
        ToolbarPickerMenu(
            L10n.Localizable.EhSettingView.Title.favoritesSortOrder,
            systemImage: "arrow.up.arrow.down.circle",
            options: FavoritesSortOrder.allCases, selection: model.sortOrder,
            optionTitle: { $0.localizedName }, onSelect: { model.setSortOrder($0) }
        )
    }
}
