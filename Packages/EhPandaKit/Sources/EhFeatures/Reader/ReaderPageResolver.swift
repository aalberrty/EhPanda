import EhModels
import EhNetworking
import Foundation

/// Resolves the pages of a gallery to image URLs: a few requests at a time, and always the
/// page nearest to where the reader is first.
///
/// Legacy resolved a whole preview page of images (20 or 40) with as many requests at once,
/// showed nothing until the last one had answered, and failed all of them when one failed.
/// Here a page takes two steps, and each is reported the moment it is done:
///
/// 1. its viewer-page link, read from the preview page that lists it. One request serves
///    every page on that preview page, however many of them are waiting;
/// 2. its image, read from the viewer page (or, for a gallery that uses the multi-page
///    viewer, from the `imagedispatch` API once the gallery's keys are known).
///
/// **Scheduling.** The reader says which pages it needs (`need`, `release`) and which one it
/// is on (`setFocus`). At most `limit` requests run. When a slot is free, the needed page
/// nearest to the focus that is still waiting gets it. While the focus page itself has no
/// image, one slot is kept for it, and if every slot is busy when the reader lands on such a
/// page, the request for the farthest page is cancelled to make room: the page being looked
/// at never waits behind pages that are not. Releasing a page cancels its request. A failure
/// stays with its page.
///
/// It lives on the main actor because the engine's data source reads page states
/// synchronously there. Everything it does itself is bookkeeping over a few dozen pages;
/// requests and parsing run inside `EhClient`, off the main actor.
public final class ReaderPageResolver {
    nonisolated public enum Event: Sendable, Equatable {
        /// Viewer-page links were read from a preview page.
        case links([Int: URL])
        /// A page has an image, for the first time or a different one after a refetch.
        case resolved(PageImage)
        case failed(page: Int, error: AppError)
        /// A page's state changed without a new image: it is waiting again, or it shows the
        /// image it already had again.
        case updated(page: Int)
    }

    nonisolated enum Status: Equatable {
        case unresolved
        case resolved
        /// Has an image that is being replaced with one from another image server.
        case refetching
        /// `waitingFor` is the shared request that failed, if that is why the page failed.
        case failed(AppError, waitingFor: Job?)
    }

    nonisolated enum Job: Hashable {
        /// The links on one preview page.
        case links(previewPage: Int)
        case mpvKeys
        /// The image of one page.
        case page(Int)
    }

    nonisolated enum Output: Sendable {
        case links([Int: URL])
        case mpvKeys(MPVKeys)
        case image(PageImage, skipServerIdentifier: String?)
    }

    private struct Running {
        let id: Int
        let task: Task<Void, Never>
    }

    public let pageCount: Int
    /// Called on the main actor, after the state it describes is in place.
    public var onEvent: ((Event) -> Void)?

    let gid: String
    let galleryURL: URL?
    let client: EhClient
    private let limit: Int

    public private(set) var paging: ReaderPreviewPaging
    var links: [Int: URL] = [:]
    var images: [Int: PageImage] = [:]
    private var statuses: [Int: Status] = [:]

    /// Set when a preview page links to the multi-page viewer; the keys come from this URL.
    var mpvURL: URL?
    /// Memory only, as in legacy: the keys belong to the session.
    public private(set) var mpvKeys: MPVKeys?
    var skipServerIdentifiers: [Int: String] = [:]

    private var needed: Set<Int> = []
    /// Pages resolved without being asked for (legacy fetched pages 1 to 3 of an MPV gallery
    /// as soon as it had the keys). They come after every needed page.
    private var eager: [Int] = []
    private var focus = 1
    private var running: [Job: Running] = [:]
    private var lastJobID = 0
    private var isPumpScheduled = false

    public init(
        gallery: Gallery, client: EhClient, previewConfig: PreviewConfig? = nil,
        maximumConcurrentRequests: Int = 4
    ) {
        gid = gallery.gid
        galleryURL = gallery.galleryURL
        pageCount = max(gallery.pageCount, 0)
        self.client = client
        limit = max(maximumConcurrentRequests, 1)
        paging = ReaderPreviewPaging(config: previewConfig)
    }

    // MARK: Reading

    public func state(of page: Int) -> ReaderPageState {
        switch status(of: page) {
        case .resolved:
            images[page].map { .image($0.imageURL) } ?? .pending
        case .failed:
            .failed
        case .unresolved, .refetching:
            .pending
        }
    }

    public func image(of page: Int) -> PageImage? {
        images[page]
    }

    public func link(of page: Int) -> URL? {
        links[page]
    }

    public func failure(of page: Int) -> AppError? {
        if case .failed(let error, _) = status(of: page) { error } else { nil }
    }

    func status(of page: Int) -> Status {
        statuses[page] ?? .unresolved
    }

    // MARK: Start-up

    /// Takes over what an earlier session stored. Call it before any page is needed.
    public func restore(previewConfig: PreviewConfig?, links: [Int: URL], images: [Int: PageImage]) {
        paging = ReaderPreviewPaging(config: previewConfig)
        for (page, link) in links where isValid(page) {
            if EhURL.isMPVURL(link) {
                // Not a viewer page. It does say where the keys are, which saves a request.
                mpvURL = mpvURL ?? link
            } else {
                self.links[page] = link
            }
        }
        for (page, image) in images where isValid(page) {
            self.images[page] = image
            statuses[page] = .resolved
        }
    }

    // MARK: Demand

    /// These pages are on screen or about to be.
    public func need(_ pages: [Int]) {
        needed.formUnion(pages.filter(isValid))
        schedulePump()
    }

    /// These pages moved out of reach. Their requests are cancelled, except a refetch the
    /// user asked for, which is short and finishes.
    public func release(_ pages: [Int]) {
        for page in pages where needed.remove(page) != nil {
            if status(of: page) != .refetching, !eager.contains(page) {
                cancel(.page(page))
            }
        }
        cancelUnwantedSharedJobs()
        schedulePump()
    }

    /// The page the reader is on. Needed pages are resolved in order of distance from it.
    public func setFocus(_ page: Int) {
        guard page != focus else { return }
        focus = page
        schedulePump()
    }

    // MARK: Commands

    /// Tries a failed page again: through another image server when it had an image (its
    /// refetch failed), from the start otherwise. Legacy did nothing in the second case.
    public func retry(_ page: Int) {
        guard isValid(page), case .failed = status(of: page) else { return }
        statuses[page] = images[page] == nil ? .unresolved : .refetching
        requestNow(page)
    }

    /// Asks for the page's image through another image server (legacy "Reload", and the retry
    /// of an image that failed to load). A page without an image is simply resolved.
    public func refetch(_ page: Int) {
        guard isValid(page) else { return }
        switch status(of: page) {
        case .refetching:
            return
        case .unresolved:
            needed.insert(page)
            schedulePump()
        case .resolved, .failed:
            statuses[page] = images[page] == nil ? .unresolved : .refetching
            requestNow(page)
        }
    }

    /// Forgets the page's image and resolves it afresh from its viewer page, without asking
    /// for another server. For an image URL that has expired, not one whose server is broken.
    public func resolveAgain(_ page: Int) {
        guard isValid(page) else { return }
        cancel(.page(page))
        images[page] = nil
        statuses[page] = .unresolved
        requestNow(page)
    }

    /// Legacy "retry all failed images": every failed page goes back to idle. One that has an
    /// image shows it again; the others resolve when they are needed.
    public func retryAllFailed() {
        for (page, status) in statuses {
            guard case .failed = status else { continue }
            statuses[page] = images[page] == nil ? .unresolved : .resolved
            onEvent?(.updated(page: page))
        }
        schedulePump()
    }

    /// Legacy "reload all images": forgets every link, image and key. Needed pages stay
    /// needed and resolve again. Sends no events; the caller reloads the reader as a whole.
    public func reset() {
        cancelAll()
        links = [:]
        images = [:]
        statuses = [:]
        mpvURL = nil
        mpvKeys = nil
        skipServerIdentifiers = [:]
        eager = []
        schedulePump()
    }

    /// Stops every request, for when the reader closes.
    public func stop() {
        cancelAll()
        needed = []
        eager = []
    }

    // MARK: Scheduling

    private func isValid(_ page: Int) -> Bool {
        page >= 1 && page <= pageCount
    }

    private func requestNow(_ page: Int) {
        needed.insert(page)
        onEvent?(.updated(page: page))
        schedulePump()
    }

    /// Runs the queue on the next turn of the main actor, so a burst of calls (the engine
    /// reports released pages, needed pages and the new current page one after the other) is
    /// seen as a whole before anything starts.
    private func schedulePump() {
        guard !isPumpScheduled else { return }
        isPumpScheduled = true
        Task { [weak self] in self?.pump() }
    }

    private func pump() {
        isPumpScheduled = false
        let focusJob = needed.contains(focus) ? nextJob(for: focus) : nil
        if let focusJob, running[focusJob] == nil {
            if running.count >= limit {
                preempt()
            }
            if running.count < limit {
                start(focusJob)
            }
        }
        // While the focus page has no image, one slot is its own.
        let slotsForOthers = focusJob == nil ? limit : limit - 1
        for page in candidates() where page != focus {
            guard let job = nextJob(for: page), running[job] == nil else { continue }
            guard running.keys.count(where: { $0 != focusJob }) < slotsForOthers else { return }
            start(job)
        }
    }

    /// Pages that may be worked on, most urgent first.
    private func candidates() -> [Int] {
        let focus = focus
        let ordered = needed.sorted { lhs, rhs in
            let left = abs(lhs - focus), right = abs(rhs - focus)
            // At the same distance the page ahead comes first.
            return left == right ? lhs > rhs : left < right
        }
        return ordered + eager.filter { !needed.contains($0) }
    }

    /// The request a page is waiting for, or `nil` when it needs none.
    private func nextJob(for page: Int) -> Job? {
        switch status(of: page) {
        case .resolved, .failed:
            return nil
        case .unresolved, .refetching:
            if mpvKeys != nil { return .page(page) }
            if mpvURL != nil { return .mpvKeys }
            if links[page] != nil { return .page(page) }
            return .links(previewPage: paging.previewPage(for: page))
        }
    }

    /// The pages whose next step is `job`.
    private func pages(waitingFor job: Job) -> [Int] {
        candidates().filter { nextJob(for: $0) == job }
    }

    private func start(_ job: Job) {
        lastJobID += 1
        let id = lastJobID
        let work = work(for: job)
        let task = Task { [weak self] in
            let result: Result<Output, any Error>
            do {
                result = .success(try await work())
            } catch {
                result = .failure(error)
            }
            self?.finish(job, id: id, result: result)
        }
        running[job] = Running(id: id, task: task)
    }

    private func cancel(_ job: Job) {
        running.removeValue(forKey: job)?.task.cancel()
    }

    private func cancelAll() {
        for entry in running.values {
            entry.task.cancel()
        }
        running = [:]
    }

    /// Frees a slot for the focus page by cancelling the request for the page farthest from
    /// it. That page stays unresolved and gets its turn again later.
    private func preempt() {
        let focus = focus
        let pages = running.keys.compactMap { job -> Int? in
            guard case .page(let page) = job, page != focus, status(of: page) != .refetching else { return nil }
            return page
        }
        guard let farthest = pages.max(by: { abs($0 - focus) < abs($1 - focus) }) else { return }
        cancel(.page(farthest))
    }

    /// A preview page or the keys are only fetched while a page is waiting for them.
    private func cancelUnwantedSharedJobs() {
        let wanted = Set(candidates().compactMap(nextJob(for:)))
        for job in Array(running.keys) where !wanted.contains(job) {
            if case .page = job { continue }
            cancel(job)
        }
    }

    // MARK: Results

    private func finish(_ job: Job, id: Int, result: Result<Output, any Error>) {
        // A cancelled or replaced request is no longer registered; its result is dropped.
        guard running[job]?.id == id else { return }
        running[job] = nil
        switch result {
        case .success(.links(let found)):
            if case .links(let previewPage) = job {
                linksDidLoad(found, previewPage: previewPage)
            }
        case .success(.mpvKeys(let keys)):
            mpvKeysDidLoad(keys)
        case .success(.image(let image, let identifier)):
            imageDidLoad(image, skipServerIdentifier: identifier)
        case .failure(let error):
            if let error = error as? AppError {
                fail(job, with: error)
            }
            // Anything else is a cancellation: the pages stay as they are.
        }
        schedulePump()
    }

    private func linksDidLoad(_ found: [Int: URL], previewPage: Int) {
        let job = Job.links(previewPage: previewPage)
        let waiting = pages(waitingFor: job)
        if let mpvLink = found.keys.sorted().lazy.compactMap({ found[$0] }).first(where: { EhURL.isMPVURL($0) }) {
            // The gallery opens in the multi-page viewer: no viewer pages, the keys are next.
            mpvURL = mpvLink
            recoverPages(failedBy: job)
            return
        }
        let learned = paging.learn(listed: found.keys, onPreviewPage: previewPage, pageCount: pageCount)
        links.merge(found) { _, new in new }
        if !found.isEmpty {
            onEvent?(.links(found))
        }
        recoverPages(failedBy: job)
        for page in waiting where links[page] == nil {
            // Not listed. If the page size turned out different, the page is on another
            // preview page and stays in the queue; otherwise it does not exist (legacy:
            // "not found" for an empty list).
            if !learned || paging.previewPage(for: page) == previewPage {
                setFailed(page, .notFound, waitingFor: job)
            }
        }
    }

    private func mpvKeysDidLoad(_ keys: MPVKeys) {
        // Legacy: the keys must cover the gallery, else "not found".
        guard keys.imageKeys.count == pageCount else {
            fail(.mpvKeys, with: .notFound)
            return
        }
        mpvKeys = keys
        eager = Array(1...min(3, max(pageCount, 1)))
        recoverPages(failedBy: .mpvKeys)
    }

    private func imageDidLoad(_ image: PageImage, skipServerIdentifier: String?) {
        var image = image
        if image.originalImageURL == nil {
            // A refetched page keeps the original it had (legacy merged with an empty list).
            image.originalImageURL = images[image.index]?.originalImageURL
        }
        images[image.index] = image
        statuses[image.index] = .resolved
        if let skipServerIdentifier {
            skipServerIdentifiers[image.index] = skipServerIdentifier
        }
        eager.removeAll { $0 == image.index }
        onEvent?(.resolved(image))
    }

    private func fail(_ job: Job, with error: AppError) {
        switch job {
        case .page(let page):
            eager.removeAll { $0 == page }
            setFailed(page, error, waitingFor: nil)
        case .links, .mpvKeys:
            // Only the pages that were waiting fail. The others ask again when their turn comes.
            for page in pages(waitingFor: job) {
                setFailed(page, error, waitingFor: job)
            }
        }
    }

    private func setFailed(_ page: Int, _ error: AppError, waitingFor job: Job?) {
        statuses[page] = .failed(error, waitingFor: job)
        onEvent?(.failed(page: page, error: error))
    }

    /// A shared request that failed earlier has now succeeded (after a retry of one of its
    /// pages): the other pages it failed recover with it.
    private func recoverPages(failedBy job: Job) {
        for (page, status) in statuses {
            guard case .failed(_, let failedJob) = status, failedJob == job else { continue }
            statuses[page] = images[page] == nil ? .unresolved : .refetching
            onEvent?(.updated(page: page))
        }
    }
}
