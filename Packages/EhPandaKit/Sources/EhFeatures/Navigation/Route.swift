import EhCore
import EhModels

/// The four tabs of the app.
nonisolated public enum AppTab: Hashable, Sendable, CaseIterable {
    case home
    /// Favorites, Watched and History.
    case library
    case search
    case settings
}

/// The gallery lists that can be pushed as their own screen. Watched and History are also
/// segments of the Library tab; Home still pushes them as screens of their own.
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
    /// Appearance › App icon.
    case appIcon
    case reading
    case laboratory
    case logs
    /// One log file in the log viewer.
    case log(LogFile)
    case about
}

/// A pushed screen.
///
/// Every screen pushed onto a tab's or the gallery sheet's `NavigationStack` is a route in that
/// stack's path, including a feature's own child screens: SwiftUI keeps path entries below
/// screens pushed with `navigationDestination(item:)`, so mixing the two drops screens from the
/// stack. Sheets and full-screen covers stay local to the feature that presents them.
nonisolated public enum Route: Hashable, Sendable {
    case galleryList(GalleryListKind)
    /// Search results for a keyword built from a tag, an uploader or a title ("detail
    /// search"). Unlike `typedSearch`, it is not added to the search history.
    case search(keyword: String)
    /// Search results for a keyword typed or picked in the Search tab; recorded in the history.
    case typedSearch(keyword: String)
    /// A gallery's detail screen. `intent` is what it should do once it has opened.
    case detail(Gallery, intent: DetailIntent? = nil)
    /// A child screen of a gallery's detail screen (comments, previews, gallery infos).
    case detailChild(DetailChildRoute)
    case settings(SettingsRoute)
}

/// A screen pushed from a gallery's detail screen. It needs the detail's model, which stays
/// alive anyway: the detail screen is below it in the same stack.
///
/// Two values are equal when they hold the same model instance and the same destination.
nonisolated public struct DetailChildRoute: Hashable, Sendable {
    public let parent: GalleryDetailModel
    public let destination: DetailDestination

    public init(parent: GalleryDetailModel, destination: DetailDestination) {
        self.parent = parent
        self.destination = destination
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.parent === rhs.parent && lhs.destination == rhs.destination
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(parent))
        hasher.combine(destination)
    }
}
