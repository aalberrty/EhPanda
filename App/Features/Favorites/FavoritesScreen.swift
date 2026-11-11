import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The Favorites tab root: one favourites folder at a time, searched on the server. Needs login.
struct FavoritesScreen: View {
    @State private var model = FavoritesModel()
    @State private var reloads = 0

    @Environment(AppRouter.self) private var appRouter
    @Environment(UserStore.self) private var userStore

    var body: some View {
        PagedGalleryList(model: model.list)
            .tagSearchable(
                text: $model.keyword, prompt: L10n.Localizable.TabItem.Title.search,
                onSubmit: { model.submitKeyword() }
            )
            .navigationTitle(
                model.category == -1 ? L10n.Localizable.FavoritesView.Title.favorites : categoryName(model.category)
            )
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ToolbarPickerMenu(
                        L10n.Localizable.FavoritesView.Title.favorites, systemImage: "dial.low",
                        options: FavoritesModel.categories, selection: model.category,
                        optionTitle: { categoryName($0) }, onSelect: { model.select(category: $0) }
                    )
                    ToolbarPickerMenu(
                        L10n.Localizable.EhSettingView.Title.favoritesSortOrder,
                        systemImage: "arrow.up.arrow.down.circle",
                        options: FavoritesSortOrder.allCases, selection: model.sortOrder,
                        optionTitle: { $0.localizedName }, onSelect: { model.setSortOrder($0) }
                    )
                    QuickSearchButton { model.isQuickSearchPresented = true }
                }
            }
            .sheet(isPresented: $model.isQuickSearchPresented) {
                QuickSearchSheet { model.quickSearch($0) }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: model.isQuickSearchPresented) { _, isShown in isShown }
            .onChange(of: appRouter.rootReselectionCount(for: .favorites)) {
                guard !model.list.needsLogin else { return }
                reloads += 1
                model.reloadForTabReselection()
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: reloads)
    }

    /// "All", the user's own folder name, or "Favorites N".
    private func categoryName(_ index: Int) -> String {
        guard index != -1 else { return L10n.Localizable.Struct.User.FavoriteCategory.all }
        return userStore.customFavoriteCategoryName(index: index)
            ?? L10n.Localizable.Struct.User.FavoriteCategory.default("\(index)")
    }
}
