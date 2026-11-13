import Dependencies
import EhCore
import Observation

/// The Library tab root: Favorites, Watched and History behind a segmented control.
///
/// Each list has its own model, which keeps its loaded pages, its search text and (through the
/// view, which keeps every opened list on screen) its scroll place while another segment shows.
/// A list loads nothing until its segment is first opened. The segment is remembered across
/// launches.
@Observable
public final class LibraryModel {
    /// A sheet of the Library tab.
    nonisolated public enum Destination: Hashable, Sendable, Identifiable {
        case quickSearch
        /// The Watched list's filters.
        case filters

        public var id: Self { self }
    }

    public private(set) var segment: LibrarySegment
    /// The segments opened so far, in `LibrarySegment.allCases` order. Their lists stay on
    /// screen while hidden; segments not opened yet have no view and load nothing.
    public private(set) var openedSegments: [LibrarySegment]
    public var destination: Destination?

    public let favorites: FavoritesModel
    public let watched: WatchedModel
    public let history: HistoryModel

    @ObservationIgnored @Dependency(\.librarySegmentStore) private var segmentStore

    /// Reads the remembered segment (a `UserDefaults` string) and starts nothing.
    public init() {
        @Dependency(\.librarySegmentStore) var store
        let segment = store.load() ?? .favorites
        self.segment = segment
        openedSegments = [segment]
        favorites = FavoritesModel()
        watched = WatchedModel()
        history = HistoryModel()
    }

    /// Shows `segment`, keeping the others as they are, and remembers it.
    public func select(_ segment: LibrarySegment) {
        guard segment != self.segment else { return }
        self.segment = segment
        if !openedSegments.contains(segment) {
            openedSegments = LibrarySegment.allCases.filter { $0 == segment || openedSegments.contains($0) }
        }
        segmentStore.save(segment)
    }

    // MARK: Search

    /// The text of the search field, which belongs to the segment on show: the server search of
    /// Favorites or Watched, or History's title filter.
    public var searchText: String {
        get {
            switch segment {
            case .favorites: favorites.keyword
            case .watched: watched.keyword
            case .history: history.titleFilter
            }
        }
        set {
            switch segment {
            case .favorites: favorites.keyword = newValue
            case .watched: watched.keyword = newValue
            case .history: history.titleFilter = newValue
            }
        }
    }

    /// Favorites and Watched search the site when the field is submitted; History filters as
    /// the user types.
    public var searchesServer: Bool { segment != .history }

    public func submitSearch() {
        switch segment {
        case .favorites: favorites.submitKeyword()
        case .watched: watched.submitKeyword()
        case .history: break
        }
    }

    /// A word picked in Quick Search closes the sheet and is searched in the segment on show.
    public func quickSearch(_ word: String) {
        destination = nil
        switch segment {
        case .favorites: favorites.quickSearch(word)
        case .watched: watched.quickSearch(word)
        case .history: break
        }
    }

    // MARK: Tab

    /// Re-selecting the tab at its root reloads Favorites or Watched (when logged in). History
    /// follows the database on its own and has nothing to reload.
    public func reloadForTabReselection() {
        switch segment {
        case .favorites: favorites.reloadForTabReselection()
        case .watched: watched.reloadForTabReselection()
        case .history: break
        }
    }
}
