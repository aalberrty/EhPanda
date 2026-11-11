import Dependencies
import EhCore
import EhModels
import EhNetworking
import Observation

/// A paginated list of galleries from one `GalleryListSource` (legacy `GenericList` and the
/// list half of every list reducer).
///
/// **Driving it from a view.** Loads run in tasks the model owns, so pushing a gallery on top
/// of the list does not abandon them; they are cancelled when the model goes away (the screen
/// left for good) or when the list is replaced. The view's tasks only start them and wait for
/// them; a cancelled view task stops waiting at once, so it does not keep the model alive:
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
    @ObservationIgnored private let tasks = ModelTasks()
    /// The first-page and next-page loads in flight. Each is cleared by its own completion, or
    /// by whatever bumps `generation` and so supersedes it.
    @ObservationIgnored private var firstPageLoad: Task<Void, Never>?
    @ObservationIgnored private var nextPageLoad: Task<Void, Never>?

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

    /// Loads the next page, skipping pages that come back empty, and waits for it.
    ///
    /// A caller cancelled before the load starts (a footer row that scrolled away as the
    /// previous page landed) starts nothing; once started, the load outlives the caller.
    public func loadMore() async {
        if let nextPageLoad {
            await nextPageLoad.waitUnlessCancelled()
            return
        }
        guard !Task.isCancelled, !needsLogin, !loadingState.isLoading, !galleries.isEmpty,
              let request = nextRequest
        else { return }
        let token = generation
        let previous = footerState
        footerState = .loading
        let fetch = pageFetch(from: request)
        let load = tasks.run(TaskKey.nextPage) { [weak self] in
            let outcome = await Outcome.of { try await fetch() }
            self?.finishNextPage(outcome, token: token, previous: previous)
        }
        nextPageLoad = load
        await load.waitUnlessCancelled()
    }

    /// Retries the failed next page.
    public func retryLoadMore() {
        paginationTrigger = PaginationTrigger(
            pagesLoaded: paginationTrigger.pagesLoaded, retries: paginationTrigger.retries + 1
        )
    }

    // MARK: Loading

    /// Starts loading `request` as the first page and waits for it (until the caller is
    /// cancelled). While a first page is already loading, waits for that one instead.
    private func loadFirstPage(_ request: PageRequest) async {
        if let firstPageLoad {
            await firstPageLoad.waitUnlessCancelled()
            return
        }
        generation += 1
        let token = generation
        let previous = loadingState
        firstRequest = request
        loadingState = .loading
        // A next page still in flight belongs to the list being replaced.
        cancelNextPage()
        let fetch = pageFetch(from: request)
        let load = tasks.run(TaskKey.firstPage) { [weak self] in
            let outcome = await Outcome.of { try await fetch() }
            self?.finishFirstPage(outcome, token: token, previous: previous)
        }
        firstPageLoad = load
        await load.waitUnlessCancelled()
    }

    private func finishFirstPage(_ outcome: Outcome<PageResult>, token: Int, previous: LoadingState) {
        guard token == generation else { return }
        firstPageLoad = nil
        switch outcome {
        case .success(let result):
            replace(with: result.page, next: result.next)
            needsLoad = false
        case .failure(let error):
            loadingState = .failed(error)
        case .cancelled:
            loadingState = previous
        }
    }

    private func finishNextPage(_ outcome: Outcome<PageResult>, token: Int, previous: LoadingState) {
        guard token == generation else { return }
        nextPageLoad = nil
        switch outcome {
        case .success(let result):
            append(result.page, next: result.next)
            footerState = .idle
        case .failure(let error):
            footerState = .failed(error)
        case .cancelled:
            footerState = previous
        }
    }

    private func cancelNextPage() {
        tasks.cancel(TaskKey.nextPage)
        nextPageLoad = nil
        footerState = .idle
    }

    /// The request for `request`'s page, holding what it needs but not the model, so a load in
    /// flight does not keep a released model alive.
    private func pageFetch(from request: PageRequest) -> @Sendable () async throws -> PageResult {
        let source = source
        let filter = source.filterRange.map { filterStore[$0] } ?? Filter()
        let client = client
        return { try await Self.fetchSkippingEmptyPages(from: request, of: source, filter: filter, client: client) }
    }

    /// Legacy: an empty page with a next page asks for the next one straight away.
    nonisolated private static func fetchSkippingEmptyPages(
        from request: PageRequest, of source: GalleryListSource, filter: Filter, client: EhClient
    ) async throws -> PageResult {
        var request = request
        while true {
            let page = try await fetch(request, of: source, filter: filter, client: client)
            let next = GalleryListPaging.nextRequest(after: page, of: source, requested: request)
            guard page.galleries.isEmpty, let next else { return PageResult(page: page, next: next) }
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
        tasks.cancel(TaskKey.firstPage)
        firstPageLoad = nil
        cancelNextPage()
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

    private enum TaskKey {
        static let firstPage = "firstPage"
        static let nextPage = "nextPage"
    }
}

/// A fetched page and the request for the page after it.
nonisolated struct PageResult: Sendable {
    let page: FetchedPage
    let next: PageRequest?
}
