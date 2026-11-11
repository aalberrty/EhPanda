import Dependencies
import EhCore
import EhDatabase
import EhModels
import Observation

/// Search results for a keyword (legacy `SearchReducer` and `DetailSearchReducer`).
///
/// A search typed in the Search tab records every keyword it searches in the history; a
/// "detail search" built from a tag, an uploader or a title does not.
@Observable
public final class SearchResultsModel {
    /// The search field's text.
    public var keyword: String
    /// The keyword the list shows results for, which is also the title. Never empty once a
    /// non-empty keyword was searched: submitting an empty field searches it again.
    public private(set) var lastKeyword: String
    public let list: GalleryListModel
    public var sheet: SearchSheet?

    public let recordsHistory: Bool
    @ObservationIgnored private var hasStarted = false

    @ObservationIgnored @Dependency(\.database) private var database

    public init(keyword: String, recordsHistory: Bool) {
        self.keyword = keyword
        lastKeyword = keyword
        self.recordsHistory = recordsHistory
        list = GalleryListModel(source: .search(keyword: keyword))
    }

    /// Records the initial search. Call from the view's `.task`; later calls do nothing.
    public func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await recordHistory(lastKeyword)
    }

    /// Searches the field's text, or the last keyword again when the field is empty.
    public func submit() async {
        await search(keyword)
    }

    /// Searches `keyword` (the last non-empty keyword when it is empty) from the first page.
    public func search(_ keyword: String) async {
        if !keyword.isEmpty {
            lastKeyword = keyword
            self.keyword = keyword
        }
        list.reset(to: .search(keyword: lastKeyword))
        await recordHistory(lastKeyword)
    }

    public func showFilters() {
        sheet = .filters
    }

    public func showQuickSearch() {
        sheet = .quickSearch
    }

    /// A word was picked in the Quick Search sheet: close it and search the word.
    public func selectQuickSearchWord(_ content: String) async {
        sheet = nil
        await search(content)
    }

    private func recordHistory(_ keyword: String) async {
        guard recordsHistory else { return }
        // Losing a history entry is not worth interrupting the search for.
        try? await database.recordSearchKeyword(keyword)
    }
}
