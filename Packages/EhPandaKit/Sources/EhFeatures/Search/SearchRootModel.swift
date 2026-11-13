import Dependencies
import EhCore
import EhDatabase
import EhModels
import Foundation
import Observation

/// The Search tab's root: the search field, quick-search words, recently searched keywords
/// and recently seen galleries.
///
/// The three lists are live database observations, so they are current whenever the root
/// becomes visible again (legacy reloaded them on every pop back to the root).
@Observable
public final class SearchRootModel {
    /// Legacy shows the 10 most recently opened galleries.
    public static let recentGalleryLimit = 10

    public var keyword = ""
    public private(set) var historyKeywords: [String] = []
    public private(set) var quickSearchWords: [QuickSearchWord] = []
    public private(set) var recentGalleries: [Gallery] = []

    public var sheet: SearchSheet?
    /// Bumped when the tab is re-selected at its root; the view restarts `observe()` on it.
    public private(set) var reloadID = 0

    // A quick-search word picked in the sheet is searched once the sheet has gone, so the
    // push does not race the dismissal (legacy waited a fixed 0.5 s).
    @ObservationIgnored private var pendingSearch: String?

    @ObservationIgnored @Dependency(\.database) private var database

    public init() {}

    /// Quick-search words as keywords, de-duplicated like legacy (same content and name).
    public var quickSearchKeywords: [SearchKeyword] {
        var seen = Set<SearchKeyword>()
        return quickSearchWords
            .map { SearchKeyword(keyword: $0.content, title: $0.name.isEmpty ? $0.content : $0.name) }
            .filter { seen.insert($0).inserted }
    }

    /// Recently searched keywords, newest first.
    public var historySearchKeywords: [SearchKeyword] {
        historyKeywords.map { SearchKeyword(keyword: $0, title: $0) }
    }

    /// Keeps the three lists current until the calling task is cancelled.
    public func observe() async {
        await withDiscardingTaskGroup { group in
            group.addTask { await self.observeHistoryKeywords() }
            group.addTask { await self.observeQuickSearchWords() }
            group.addTask { await self.observeRecentGalleries() }
        }
    }

    // An observation only fails when the database itself does; the list then stays as it was.

    private func observeHistoryKeywords() async {
        do {
            for try await keywords in database.observeSearchHistory() { historyKeywords = keywords }
        } catch {}
    }

    private func observeQuickSearchWords() async {
        do {
            for try await words in database.observeQuickSearchWords() { quickSearchWords = words }
        } catch {}
    }

    private func observeRecentGalleries() async {
        do {
            for try await galleries in database.observeHistory(limit: Self.recentGalleryLimit) {
                recentGalleries = galleries
            }
        } catch {}
    }

    // MARK: Actions

    public func submit(on stack: StackRouter) {
        search(keyword, on: stack)
    }

    /// Pushes the results screen for `keyword` as `Route.typedSearch`, whose results screen
    /// records the search history.
    public func search(_ keyword: String, on stack: StackRouter) {
        self.keyword = keyword
        stack.push(.typedSearch(keyword: keyword))
    }

    public func removeHistoryKeyword(_ keyword: String) async {
        try? await database.removeSearchKeyword(keyword)
    }

    public func showFilters() {
        sheet = .filters
    }

    public func showQuickSearch() {
        sheet = .quickSearch
    }

    /// With no saved words, the Quick Search section offers to add the first one.
    public func addQuickSearchWord() {
        sheet = .newQuickSearchWord
    }

    /// A word was picked in the Quick Search sheet: close it, then search once it is gone.
    public func selectQuickSearchWord(_ content: String) {
        keyword = content
        pendingSearch = content
        sheet = nil
    }

    public func sheetDismissed(on stack: StackRouter) {
        guard let pendingSearch else { return }
        self.pendingSearch = nil
        search(pendingSearch, on: stack)
    }

    /// The Search tab was tapped while already showing this root: reload the lists.
    /// (Re-selecting it with results pushed pops the whole stack in `AppRouter.select`.)
    public func rootReselected() {
        reloadID += 1
    }

    // MARK: Layout

    /// How many keywords a section shows: 10 in compact width, 20 in regular width (legacy
    /// iPhone / iPad). The Quick Search sheet lists every word.
    nonisolated public static func keywordLimit(isRegularWidth: Bool) -> Int {
        isRegularWidth ? 20 : 10
    }

    /// The keywords a section shows, in rows of two (left to right, then down).
    nonisolated public static func keywordRows<Item>(_ items: [Item], isRegularWidth: Bool) -> [[Item]] {
        let limited = Array(items.prefix(keywordLimit(isRegularWidth: isRegularWidth)))
        return stride(from: 0, to: limited.count, by: 2).map { Array(limited[$0..<min($0 + 2, limited.count)]) }
    }
}

/// A search keyword and the text shown for it.
nonisolated public struct SearchKeyword: Hashable, Sendable {
    public let keyword: String
    public let title: String

    public init(keyword: String, title: String) {
        self.keyword = keyword
        self.title = title
    }

    /// The title split after a leading namespace such as `language:` or `f:`, which a chip
    /// draws quieter than the rest. `nil` when the title has no such prefix.
    public var namespacedTitle: (namespace: String, value: String)? {
        guard let colon = title.firstIndex(of: ":") else { return nil }
        let namespace = title[...colon]
        let value = title[title.index(after: colon)...]
        guard namespace.count > 1, !value.isEmpty, !namespace.contains(where: \.isWhitespace) else { return nil }
        return (String(namespace), String(value))
    }
}

/// Sheets shown by the search screens.
nonisolated public enum SearchSheet: Hashable, Identifiable, Sendable {
    case filters
    case quickSearch
    /// The Quick Search sheet, opened on the form for a new word.
    case newQuickSearchWord

    public var id: Self { self }
}
