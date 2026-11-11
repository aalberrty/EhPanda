import Dependencies
import EhCore
import EhModels
import EhNetworking
import Observation

/// A paginated list of galleries from one `GalleryListSource` (legacy `GenericList` and the
/// list half of every list reducer).
///
/// **Driving it from a view.** Every load runs in a task the view owns, so leaving the screen
/// cancels it, and a cancelled load leaves the state as it was:
/// - `.task(id: model.loadTrigger) { await model.loadIfNeeded() }` performs the first load, and
///   loads again after `retry()`, `reload()`, `reset(to:)` or `jumpToPage(_:)`, and when the screen
///   swaps in another list (a Toplists period, a Favorites folder);
/// - `.refreshable { await model.refresh() }`;
/// - the pagination footer runs `.task(id: model.paginationTrigger) { await model.loadMore() }`,
///   so the next page loads when the end of the list comes into view, again after each page
///   lands while the end is still visible, and after `retryLoadMore()`.
@Observable
public final class GalleryListModel {
    /// What the list area shows.
    public enum Phase: Equatable, Sendable {
        /// The source requires login and the user is not logged in; nothing was requested.
        case notLoggedIn
        case loading
        /// The first page failed, or came back empty (`.notFound`).
        case failed(AppError)
        case content
    }

    /// The row after the last gallery.
    public enum FooterPhase: Equatable, Sendable {
        /// More pages follow.
        case idle
        case loading
        case failed
        /// No more pages.
        case end
    }

    /// The id of the view task that runs `loadIfNeeded()`.
    public struct LoadTrigger: Hashable, Sendable {
        /// A screen that swaps in another list keeps the same view, and a new list's request
        /// counter starts at 0 like every other's, so the list's identity must be part of the id.
        /// The list shown before a swap is still retained by its screen, so its identifier
        /// cannot be reused by the new list.
        let list: ObjectIdentifier
        let request: Int
    }

    public struct PaginationTrigger: Hashable, Sendable {
        let pagesLoaded: Int
        let retries: Int
    }

    public private(set) var source: GalleryListSource
    public private(set) var galleries: [Gallery] = [] {
        didSet { updateVisibleGalleries() }
    }
    /// `galleries` whose title contains `titleFilter` (legacy local "Filter" search field).
    public private(set) var visibleGalleries: [Gallery] = []
    public var titleFilter = "" {
        didSet {
            if titleFilter != oldValue { updateVisibleGalleries() }
        }
    }
    public private(set) var pageNumber = PageNumber()
    /// State of the first page (and of refreshes).
    public private(set) var loadingState: LoadingState = .idle
    /// State of the next page.
    public private(set) var footerState: LoadingState = .idle
    public private(set) var needsLogin = false
    /// The favourites order the server reported with the last page (favourites only).
    public private(set) var favoritesSortOrder: FavoritesSortOrder?
    /// Bumped whenever the view should run `loadIfNeeded()` again.
    private(set) var loadRequest = 0
    public private(set) var paginationTrigger = PaginationTrigger(pagesLoaded: 0, retries: 0)
    private(set) var nextRequest: PageRequest?

    @ObservationIgnored private var firstRequest: PageRequest = .first
    @ObservationIgnored private var needsLoad = true
    /// Bumped by every load that replaces the list; results of older loads are dropped.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var galleryIDs = Set<String>()

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.filterStore) private var filterStore
    @ObservationIgnored @Dependency(\.cookieStore) private var cookieStore

    public init(source: GalleryListSource) {
        self.source = source
    }

    // MARK: Derived state

    public var phase: Phase {
        if needsLogin { return .notLoggedIn }
        if let error = loadingState.failed { return .failed(error) }
        return galleries.isEmpty ? .loading : .content
    }

    public var footerPhase: FooterPhase {
        switch footerState {
        case .loading: .loading
        case .failed: .failed
        case .idle: hasNextPage ? .idle : .end
        }
    }

    /// Changes whenever the view should run `loadIfNeeded()` again, including when the view is
    /// handed a different list.
    public var loadTrigger: LoadTrigger {
        LoadTrigger(list: ObjectIdentifier(self), request: loadRequest)
    }

    public var hasNextPage: Bool { nextRequest != nil }

    /// Whether the jump-page control applies: a numbered source with more than one page.
    public var canJumpPage: Bool {
        source.supportsPageJump && !pageNumber.isSinglePage
    }

    /// The last page, 1-based, for numbered sources.
    public var maximumPage: Int { pageNumber.maximum + 1 }

    // MARK: Commands

    /// Loads the first page unless it is loaded already. Checks the login first, so a screen that
    /// needed a login loads by itself once the user comes back logged in.
    public func loadIfNeeded() async {
        guard updateLoginState(), needsLoad else { return }
        await loadFirstPage(firstRequest)
    }

    /// Reloads the first page, keeping the current galleries on screen until it arrives.
    public func refresh() async {
        guard updateLoginState() else { return }
        await loadFirstPage(.first)
    }

    /// Retries the failed first page.
    public func retry() {
        needsLoad = true
        loadRequest += 1
    }

    /// Clears the list and loads the first page again (tab re-selection).
    public func reload() {
        startOver(from: .first)
    }

    /// Switches to `source` and loads it, even when it is the current one (a resubmitted keyword
    /// reloads, like legacy).
    public func reset(to source: GalleryListSource) {
        self.source = source
        startOver(from: .first)
    }

    /// Loads the given 1-based page of a numbered source. Returns `false`, changing nothing, when
    /// `input` is not a page number between 1 and `maximumPage`.
    @discardableResult
    public func jumpToPage(_ input: String) -> Bool {
        guard source.supportsPageJump,
              let page = Int(input.trimmingCharacters(in: .whitespaces)),
              (1...maximumPage).contains(page)
        else { return false }
        startOver(from: .page(page - 1))
        return true
    }

    /// Loads the next page, skipping pages that come back empty.
    public func loadMore() async {
        guard !needsLogin, !loadingState.isLoading, !footerState.isLoading, !galleries.isEmpty,
              let request = nextRequest
        else { return }
        let token = generation
        let previous = footerState
        footerState = .loading
        do {
            let (page, next) = try await fetchSkippingEmptyPages(from: request)
            guard token == generation else { return }
            try Task.checkCancellation()
            append(page, next: next)
            footerState = .idle
        } catch {
            guard token == generation else { return }
            footerState = Self.isCancellation(error) ? previous : .failed(Self.appError(error))
        }
    }

    /// Retries the failed next page.
    public func retryLoadMore() {
        paginationTrigger = PaginationTrigger(
            pagesLoaded: paginationTrigger.pagesLoaded, retries: paginationTrigger.retries + 1
        )
    }

    // MARK: Loading

    private func loadFirstPage(_ request: PageRequest) async {
        guard !loadingState.isLoading else { return }
        generation += 1
        let token = generation
        let previous = loadingState
        firstRequest = request
        loadingState = .loading
        // A next page still in flight belongs to the list being replaced; its result is dropped.
        footerState = .idle
        do {
            let (page, next) = try await fetchSkippingEmptyPages(from: request)
            guard token == generation else { return }
            try Task.checkCancellation()
            replace(with: page, next: next)
            needsLoad = false
        } catch {
            guard token == generation else { return }
            if Self.isCancellation(error) {
                loadingState = previous
            } else {
                loadingState = .failed(Self.appError(error))
            }
        }
    }

    /// Legacy: an empty page with a next page asks for the next one straight away.
    private func fetchSkippingEmptyPages(from request: PageRequest) async throws -> (FetchedPage, PageRequest?) {
        let source = source
        let filter = source.filterRange.map { filterStore[$0] } ?? Filter()
        var request = request
        while true {
            let page = try await Self.fetch(request, of: source, filter: filter, client: client)
            let next = GalleryListPaging.nextRequest(after: page, of: source, requested: request)
            guard page.galleries.isEmpty, let next else { return (page, next) }
            request = next
        }
    }

    private func replace(with page: FetchedPage, next: PageRequest?) {
        let unique = GalleryListPaging.deduplicated(page.galleries, excluding: [])
        galleryIDs = Set(unique.map(\.gid))
        galleries = unique
        apply(page, next: next)
        footerState = .idle
        loadingState = unique.isEmpty ? .failed(.notFound) : .idle
    }

    private func append(_ page: FetchedPage, next: PageRequest?) {
        let unique = GalleryListPaging.deduplicated(page.galleries, excluding: galleryIDs)
        galleryIDs.formUnion(unique.map(\.gid))
        if !unique.isEmpty {
            galleries.append(contentsOf: unique)
        }
        apply(page, next: next)
    }

    private func apply(_ page: FetchedPage, next: PageRequest?) {
        pageNumber = page.pageNumber
        nextRequest = next
        if case .favorites = source {
            favoritesSortOrder = page.sortOrder
        }
        paginationTrigger = PaginationTrigger(
            pagesLoaded: paginationTrigger.pagesLoaded + 1, retries: paginationTrigger.retries
        )
    }

    /// Forgets everything loaded and asks the view to load `request`.
    private func startOver(from request: PageRequest) {
        generation += 1
        galleryIDs = []
        galleries = []
        pageNumber = PageNumber()
        nextRequest = nil
        loadingState = .idle
        footerState = .idle
        firstRequest = request
        needsLoad = true
        loadRequest += 1
    }

    private func updateLoginState() -> Bool {
        let needsLogin = source.requiresLogin && !cookieStore.didLogin
        if self.needsLogin != needsLogin {
            self.needsLogin = needsLogin
        }
        return !needsLogin
    }

    private func updateVisibleGalleries() {
        visibleGalleries = GalleryListPaging.filtered(galleries, byTitle: titleFilter)
    }

    nonisolated private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || Task.isCancelled
    }

    nonisolated private static func appError(_ error: any Error) -> AppError {
        error as? AppError ?? .unknown
    }
}
