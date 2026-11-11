import EhModels

/// The four tabs of the app.
nonisolated public enum AppTab: Hashable, Sendable, CaseIterable {
    case home
    case favorites
    case search
    case settings
}

/// The gallery lists that can be pushed as their own screen.
nonisolated public enum GalleryListKind: Hashable, Sendable {
    case frontpage
    case popular
    case watched
    case toplists
    case history
}

/// Screens of the Settings tab.
nonisolated public enum SettingsRoute: Hashable, Sendable {
    case account
    case login
    case ehSetting
    case general
    case appearance
    case reading
    case laboratory
    case logs
    case about
}

/// A screen that one feature can ask another to show.
///
/// Routes are for **cross-feature** navigation only: opening a gallery, a list or a search
/// from anywhere. Child screens that need their parent's model (comments, previews,
/// archives, …) are presented locally by the parent with `navigationDestination(item:)`
/// or a sheet, driven by a `destination` property on the parent's model.
nonisolated public enum Route: Hashable, Sendable {
    case galleryList(GalleryListKind)
    /// Search results for a keyword built from a tag, an uploader or a title ("detail
    /// search"). Unlike a search typed in the Search tab, it is not added to the search history.
    case search(keyword: String)
    case detail(Gallery)
    case settings(SettingsRoute)
}
