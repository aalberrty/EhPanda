import Dependencies
import EhCore
import EhModels
import Observation

/// One chip of the Favorites folder row.
nonisolated public struct FavoriteFolder: Identifiable, Hashable, Sendable {
    /// `-1` (every folder) or the folders 0–9.
    public let index: Int
    /// The user's own name for the folder; `nil` for "All" and for folders that keep the site's
    /// default name ("Favorites N"), which the app localizes.
    public let customName: String?

    public var id: Int { index }
    public var isAll: Bool { index == -1 }
}

/// The Favorites list of the Library tab. Each folder keeps its own list, page and loading state,
/// so switching back shows what was already loaded.
@Observable
public final class FavoritesModel {
    /// `-1` (every folder) and the folders 0–9, in chip order.
    public static let categories = Array(-1...9)

    /// The selected folder; `-1` is every folder.
    public private(set) var category = -1
    public private(set) var list: GalleryListModel
    /// The search field's text. Only submitting it reloads the list.
    public var keyword = ""

    @ObservationIgnored private var lists: [Int: GalleryListModel]
    /// Unused directly: `withDependencies(from: self)` reads the dependencies it captured, so
    /// lists made after `init` use the same client and stores as the first one.
    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.userStore) private var userStore
    /// The keyword the lists were loaded with.
    @ObservationIgnored private var submittedKeyword = ""

    public init() {
        let list = GalleryListModel(source: .favorites(category: -1, keyword: "", sortOrder: nil))
        self.list = list
        lists = [-1: list]
    }

    /// The order the server reported for the current folder.
    public var sortOrder: FavoritesSortOrder? { list.favoritesSortOrder }

    /// "All", then every folder with the name the user gave it on the site. Reads only the folder
    /// names of the user store, so the chips re-render when a name changes and at no other time.
    public var folders: [FavoriteFolder] {
        Self.categories.map { index in
            FavoriteFolder(index: index, customName: index == -1 ? nil : userStore.customFavoriteCategoryName(index: index))
        }
    }

    /// Shows `category`, reusing its list if it was loaded before.
    public func select(category: Int) {
        guard category != self.category else { return }
        self.category = category
        let list = lists[category] ?? makeList(category: category, keyword: submittedKeyword)
        lists[category] = list
        self.list = list
    }

    /// Asks the server to sort favourites by `order` and reloads. This changes the account's
    /// own setting, so every other folder's list is out of date and is dropped.
    public func setSortOrder(_ order: FavoritesSortOrder) {
        guard order != sortOrder else { return }
        lists = [category: list]
        list.reset(to: .favorites(category: category, keyword: submittedKeyword, sortOrder: order))
    }

    /// Searches the current folder for the field's text. Other folders' lists were loaded with
    /// the old keyword and are dropped.
    public func submitKeyword() {
        submittedKeyword = keyword
        lists = [category: list]
        list.reset(to: .favorites(category: category, keyword: keyword, sortOrder: nil))
    }

    /// A word picked in Quick Search replaces the field's text and is searched.
    public func quickSearch(_ word: String) {
        keyword = word
        submitKeyword()
    }

    /// Re-selecting the tab at its root reloads the current folder (only when logged in, which
    /// the list checks when it loads).
    public func reloadForTabReselection() {
        guard !list.needsLogin else { return }
        list.reload()
    }

    /// Lists made later still use this model's dependencies.
    private func makeList(category: Int, keyword: String) -> GalleryListModel {
        withDependencies(from: self) {
            GalleryListModel(source: .favorites(category: category, keyword: keyword, sortOrder: nil))
        }
    }
}
