import Dependencies
import EhCore
import EhDatabase
import EhModels
import EhNetworking
import Foundation
import Observation

/// The previews grid: one cell per page, its preview loaded with the preview page that holds it.
///
/// A preview page (the site's `p`) is fetched when one of its cells appears without a preview,
/// and cancelled if all of its cells leave the screen first, so the number of requests in flight
/// is bounded by what is visible however fast the grid is flung.
///
/// A preview page is asked for once. One that failed stays failed until the user taps one of
/// its cells: the site bans addresses for request volume, so a page that cannot be had (an
/// outage, a ban page) must not be requested again for each of its 20 to 40 cells that scrolls
/// into view.
@Observable
public final class PreviewsModel {
    public let gallery: Gallery
    public let pageCount: Int

    /// Known previews by 1-based page.
    public private(set) var thumbnails: [Int: PreviewThumbnail] = [:]
    /// The reader, when a preview was tapped.
    public var readerDestination: DetailDestination?

    /// Preview pages whose request failed. Their cells show the failure until one is tapped.
    private var failedPages: Set<Int> = []
    /// Preview pages that were fetched. A cell of one that still has no preview was not on it.
    private var fetchedPages: Set<Int> = []
    /// Starts from the detail page's layout and corrects itself from what preview pages list.
    /// Observed with the two sets above: together they decide whether a cell has failed.
    private var paging: PreviewPaging
    @ObservationIgnored private var isReady = false
    @ObservationIgnored private var loadingPages: Set<Int> = []
    @ObservationIgnored private var visibleIndices: Set<Int> = []
    @ObservationIgnored private let tasks = ModelTasks()

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.database) private var database

    /// - Parameters:
    ///   - config: The detail page's preview layout; legacy assumed four normal rows without one.
    ///   - previewURLs: Previews the detail screen already knows.
    public init(gallery: Gallery, pageCount: Int, config: PreviewConfig?, previewURLs: [Int: URL]) {
        self.gallery = gallery
        self.pageCount = pageCount
        paging = PreviewPaging(config: config)
        thumbnails = previewURLs.reduce(into: [:]) { $0[$1.key] = PreviewThumbnail(index: $1.key, url: $1.value) }
    }

    public func preview(at index: Int) -> PreviewThumbnail? {
        thumbnails[index]
    }

    /// Whether the cell has no preview and none on the way: the request for its preview page
    /// failed, or the page arrived without listing it.
    public func hasFailed(at index: Int) -> Bool {
        guard thumbnails[index] == nil else { return false }
        let page = page(of: index)
        return failedPages.contains(page) || fetchedPages.contains(page)
    }

    /// Adds the stored previews, then fetches whatever visible cell still has none.
    public func load() async {
        guard !isReady else { return }
        let stored = (try? await database.pages(gid: gallery.gid)) ?? []
        var merged = thumbnails
        for page in stored {
            guard merged[page.index] == nil, let url = page.previewURL else { continue }
            merged[page.index] = PreviewThumbnail(index: page.index, url: url)
        }
        if merged != thumbnails {
            thumbnails = merged
        }
        isReady = true
        for index in visibleIndices.sorted() {
            loadPageIfNeeded(for: index)
        }
    }

    public func thumbnailAppeared(_ index: Int) {
        visibleIndices.insert(index)
        loadPageIfNeeded(for: index)
    }

    public func thumbnailDisappeared(_ index: Int) {
        visibleIndices.remove(index)
        let page = page(of: index)
        guard loadingPages.contains(page), !visibleIndices.contains(where: { self.page(of: $0) == page }) else { return }
        loadingPages.remove(page)
        tasks.cancel(Self.taskKey(page))
    }

    /// A tap on a cell. One whose preview failed asks for its preview page again, which is the
    /// only way a failed page is retried; any other opens the reader there.
    public func select(_ index: Int) {
        if hasFailed(at: index) {
            let page = page(of: index)
            failedPages.remove(page)
            fetchedPages.remove(page)
            loadPageIfNeeded(for: index)
        } else {
            openReader(at: index)
        }
    }

    /// Opens the reader at `index`, which also becomes the reading progress.
    private func openReader(at index: Int) {
        let database = database
        let gid = gallery.gid
        Task { try? await database.updateReadingProgress(gid: gid, progress: index) }
        readerDestination = .reader(page: index)
    }

    // MARK: Paging

    private func page(of index: Int) -> Int {
        paging.previewPage(for: index)
    }

    private func loadPageIfNeeded(for index: Int) {
        let page = page(of: index)
        guard isReady, thumbnails[index] == nil, !loadingPages.contains(page),
              !failedPages.contains(page), !fetchedPages.contains(page),
              let galleryURL = gallery.galleryURL
        else { return }
        loadingPages.insert(page)
        let client = client
        tasks.run(Self.taskKey(page)) { [weak self] in
            let outcome = await Outcome.of { try await client.previewPage(galleryURL: galleryURL, pageNumber: page) }
            self?.finishPage(page, outcome)
        }
    }

    private func finishPage(_ page: Int, _ outcome: Outcome<PreviewPage>) {
        switch outcome {
        case .cancelled:
            // Its cells left the screen, which also took it out of `loadingPages`.
            return
        case .failure:
            loadingPages.remove(page)
            failedPages.insert(page)
        case .success(let listed) where listed.previewURLs.isEmpty:
            // Legacy: an empty list is "not found".
            loadingPages.remove(page)
            failedPages.insert(page)
        case .success(let listed):
            loadingPages.remove(page)
            fetchedPages.insert(page)
            merge(listed)
            guard paging.learn(listed: listed.indices, onPreviewPage: page, pageCount: pageCount) else { return }
            // The page size was not what the layout said: cells still without a preview are
            // listed on another preview page than the one that was asked for them.
            for index in visibleIndices.sorted() {
                loadPageIfNeeded(for: index)
            }
        }
    }

    /// New previews never replace known ones on screen, as in legacy. Everything the page
    /// lists is stored, viewer links included: the reader opened from here starts from them.
    private func merge(_ listed: PreviewPage) {
        var merged = thumbnails
        for (index, url) in listed.previewURLs where merged[index] == nil {
            merged[index] = PreviewThumbnail(index: index, url: url)
        }
        if merged != thumbnails {
            thumbnails = merged
        }
        let database = database
        let pages = GalleryPage.pages(gid: gallery.gid, listedOn: listed)
        Task { try? await database.upsertPages(pages) }
    }

    private static func taskKey(_ page: Int) -> String {
        "page\(page)"
    }
}
