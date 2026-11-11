import EhModels

extension User {
    /// The display name of favorites folder `index`; `-1` means all folders.
    func getFavoriteCategory(index: Int) -> String {
        guard index != -1 else { return L10n.Localizable.Struct.User.FavoriteCategory.all }
        return customFavoriteCategoryName(index: index)
            ?? L10n.Localizable.Struct.User.FavoriteCategory.default("\(index)")
    }
}
