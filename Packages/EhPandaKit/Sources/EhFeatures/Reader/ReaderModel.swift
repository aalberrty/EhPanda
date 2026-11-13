import Dependencies
import EhCore
import EhDatabase
import EhModels
import EhNetworking
import Foundation
import Observation

/// The commands the reader model sends to the reader engine. The screen fills them in when it
/// connects the engine, and tests record them.
public struct ReaderEngineCommands {
    /// A page's state or aspect ratio changed. Also makes the engine load a failed image again.
    public var reloadPage: (Int) -> Void
    /// Everything about the pages changed.
    public var reloadData: () -> Void
    public var scrollToPage: (Int) -> Void
    /// Goes to the next page or spread; `false` at the end of the gallery.
    public var advance: () -> Bool

    public init(
        reloadPage: @escaping (Int) -> Void, reloadData: @escaping () -> Void,
        scrollToPage: @escaping (Int) -> Void, advance: @escaping () -> Bool
    ) {
        self.reloadPage = reloadPage
        self.reloadData = reloadData
        self.scrollToPage = scrollToPage
        self.advance = advance
    }
}

/// The reader of one gallery (legacy `ReadingReducer` and the handlers of `ReadingView`).
///
/// It is the engine's host: it answers what each page is (`pageState(at:)`,
/// `aspectRatio(at:)`), takes the engine's events (the `…Did…` methods), and tells the engine
/// what changed through `engine`. Page states are deliberately not observable: the engine
/// asks for them and is told about changes page by page, so a page that resolves touches that
/// page's view and nothing in SwiftUI.
///
/// The observable properties are the control panel's. The screen creates the engine once
/// `isReady` is set, by `start()`, which the view runs in its `.task`.
@Observable
public final class ReaderModel {
    nonisolated public enum Destination: Identifiable, Hashable, Sendable {
        /// The reading settings sheet.
        case settings
        /// The share sheet for a page's image, which was written to this file.
        case share(URL)

        public var id: Self { self }
    }

    /// A short message for the HUD.
    nonisolated public enum Notice: Sendable, Equatable {
        case copiedToClipboard
        case savedToPhotoLibrary
        case error
    }

    public let gallery: Gallery
    public let pageCount: Int

    // MARK: Observable state

    /// Whether what was stored for the gallery has been read. The engine is created after that,
    /// so it opens on the right page and with the stored URLs and sizes.
    public private(set) var isReady = false
    /// The page to open on: the requested one, or the stored reading progress.
    public private(set) var initialPage = 1
    public internal(set) var currentPage = 1
    /// What the slider and the page indicator show: the current page, or the page being
    /// scrubbed to while the preview strip is up.
    public internal(set) var sliderPage = 1
    public var showsPanel = false
    public internal(set) var showsSliderPreview = false
    public internal(set) var autoPlay: ReaderAutoPlayPolicy = .off
    public var isLiveTextEnabled = false
    public var destination: Destination? {
        didSet {
            // Legacy: any sheet turns auto-play off.
            if destination != nil { setAutoPlay(.off) }
        }
    }
    public var notice: Notice?
    /// Slider thumbnails by page, as stored (a sprite-sheet tile carries its crop in the URL).
    public internal(set) var previewURLs: [Int: URL] = [:]
    /// How many thumbnails the preview strip shows; the view sets it for its size with
    /// `previewStripLength(isRegularWidth:isLandscape:)`.
    public var previewStripLength = 5
    /// How long the first page took to appear after the reader opened.
    public private(set) var timeToFirstPage: Duration?
    /// The gallery's detail page, for its titles: the opener's, else what is stored. A list's
    /// gallery carries neither the detail's title nor its Japanese title.
    private var detail: GalleryDetail?

    // MARK: Engine

    @ObservationIgnored public var engine: ReaderEngineCommands?

    // MARK: Internals

    @ObservationIgnored let resolver: ReaderPageResolver
    @ObservationIgnored let writer: ReaderPageWriter
    @ObservationIgnored let previews: ReaderPreviewLoader
    @ObservationIgnored private let requestedPage: Int?
    @ObservationIgnored var aspectRatios: [Int: CGFloat] = [:]
    /// Pages whose image size is in the database.
    @ObservationIgnored var sizedPages: Set<Int> = []
    /// Pages whose image URL comes from an earlier session and has not loaded yet. Such a URL
    /// may have expired; if it fails, the page is resolved again once without being asked.
    @ObservationIgnored var staleCandidates: Set<Int> = []
    /// Pages whose image failed to download or decode, as the engine reported.
    @ObservationIgnored var failedImagePages: Set<Int> = []
    @ObservationIgnored private var openedAt: ContinuousClock.Instant?
    @ObservationIgnored private var isClosed = false
    @ObservationIgnored var autoPlayTask: Task<Void, Never>?
    @ObservationIgnored var previewDebounce: Task<Void, Never>?
    @ObservationIgnored var actionTasks: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored var lastActionID = 0
    /// The file the share sheet was last given.
    @ObservationIgnored var sharedFile: URL?

    @ObservationIgnored @Dependency(\.database) private var database
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.applicationClient) var application
    @ObservationIgnored @Dependency(\.clipboardClient) var clipboard
    @ObservationIgnored @Dependency(\.photoLibraryClient) var photoLibrary
    @ObservationIgnored @Dependency(\.imageCacheClient) var imageCache
    @ObservationIgnored @Dependency(\.continuousClock) var clock
    @ObservationIgnored @Dependency(\.appLogger) private var logger

    /// - Parameters:
    ///   - initialPage: 1-based; `nil` opens at the stored reading progress.
    ///   - detail: The gallery's detail page when the opener has it (the detail screen does);
    ///     otherwise `start()` reads the stored one.
    public init(gallery: Gallery, initialPage: Int? = nil, detail: GalleryDetail? = nil) {
        @Dependency(\.ehClient) var client
        @Dependency(\.database) var database
        @Dependency(\.continuousClock) var clock
        @Dependency(\.appLogger) var logger
        self.gallery = gallery
        self.detail = detail
        pageCount = max(gallery.pageCount, 0)
        requestedPage = initialPage
        let previews = ReaderPreviewLoader(galleryURL: gallery.galleryURL, client: client)
        self.previews = previews
        // The resolver reads preview pages through the loader the slider uses, so a preview
        // page is requested once whichever of them wants it first.
        resolver = ReaderPageResolver(gallery: gallery, client: client) { [previews] number in
            try await previews.page(number)
        }
        writer = ReaderPageWriter(gid: gallery.gid, database: database, clock: clock, logger: logger)
        resolver.onEvent = { [weak self] in self?.handle($0) }
        previews.onLoad = { [weak self] in self?.previewPageDidLoad($0, previewPage: $1) }
    }

    // MARK: Lifecycle

    /// Reads what is stored for the gallery and gets the reader ready to show pages.
    public func start() async {
        guard !isReady, !isClosed else { return }
        openedAt = .now
        if settings.enablesLandscape {
            application.setOrientationLock(.unlocked)
        }
        let database = database
        let gid = gallery.gid
        async let storedPages = database.pages(gid: gid)
        // Only the progress and the preview layout: the tags and comments stored next to them
        // would be decoded for nothing, in front of the first page.
        async let storedState = database.readingState(gid: gid)
        let pages = (try? await storedPages) ?? []
        let state = try? await storedState
        guard !isClosed, !isReady else { return }
        restore(pages: pages, state: state)
        isReady = true
        // Only the title needs it, so it is read once the engine can show the first page.
        if detail == nil, let stored = try? await database.detail(gid: gid), !isClosed {
            detail = stored
        }
    }

    /// The title the detail page shows: the Japanese title when preferred and present, else the
    /// detail's title; the list's title until a detail is known.
    public func title(prefersJapanese: Bool) -> String {
        detail?.title(prefersJapanese: prefersJapanese) ?? gallery.title
    }

    /// Stops all work and saves what is left to save. Call it when the reader goes away.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        setAutoPlay(.off)
        previewDebounce?.cancel()
        resolver.stop()
        previews.stop()
        for task in actionTasks.values {
            task.cancel()
        }
        actionTasks = [:]
        writer.flush()
        removeSharedFile()
        // Legacy: back to portrait on everything but the iPad.
        if !application.isPad() {
            application.setOrientationLock(.portrait)
        }
    }

    /// The landscape setting applies at once while reading (legacy `onChange` of the setting).
    public func enablesLandscapeDidChange(_ isEnabled: Bool) {
        guard !isClosed, !application.isPad() else { return }
        application.setOrientationLock(isEnabled ? .unlocked : .portrait)
    }

    /// The landscape toggle of the reading settings is for iPhone only.
    public var showsLandscapeSetting: Bool { !application.isPad() }

    /// Returns when everything saved so far is in the database.
    func waitUntilSaved() async {
        await writer.waitUntilWritten()
    }

    private func restore(pages: [GalleryPage], state: ReadingState?) {
        var links: [Int: URL] = [:]
        var images: [Int: PageImage] = [:]
        for page in pages where page.index >= 1 && page.index <= pageCount {
            links[page.index] = page.pageURL
            if let imageURL = page.imageURL {
                images[page.index] = PageImage(
                    index: page.index, imageURL: imageURL, originalImageURL: page.originalImageURL
                )
            }
            if let width = page.imageWidth, let height = page.imageHeight, width > 0, height > 0 {
                aspectRatios[page.index] = CGFloat(width) / CGFloat(height)
                sizedPages.insert(page.index)
            }
            previewURLs[page.index] = page.previewURL
        }
        staleCandidates = Set(images.keys)
        resolver.restore(previewConfig: state?.previewConfig, links: links, images: images)

        let savedProgress = state?.readingProgress ?? 0
        let page = min(max(requestedPage ?? savedProgress, 1), max(pageCount, 1))
        initialPage = page
        currentPage = page
        sliderPage = page
        resolver.setFocus(page)
        if requestedPage != nil, page != savedProgress {
            // Opened on a chosen page (legacy saved it before presenting the reader).
            writer.setProgress(page)
        }
    }

    // MARK: Engine data source

    public func pageState(at page: Int) -> ReaderPageState {
        resolver.state(of: page)
    }

    /// Width / height of a page's image, from an earlier session or from this one.
    public func aspectRatio(at page: Int) -> CGFloat? {
        aspectRatios[page]
    }

    // MARK: Engine events

    public func currentPageDidChange(_ page: Int) {
        currentPage = page
        if !showsSliderPreview {
            sliderPage = page
        }
        resolver.setFocus(page)
        writer.setProgress(page)
        // Legacy kept turning at the end; there is nowhere to go from the last page.
        if autoPlay != .off, page >= pageCount {
            setAutoPlay(.off)
        }
    }

    public func pagesNeeded(_ pages: [Int]) {
        resolver.need(pages)
    }

    public func pagesNoLongerNeeded(_ pages: [Int]) {
        resolver.release(pages)
    }

    /// A page's image is on screen, decoded at `pixelSize`.
    public func imageDidLoad(page: Int, pixelSize: CGSize) {
        failedImagePages.remove(page)
        staleCandidates.remove(page)
        noteFirstPage()
        guard pixelSize.width > 0, pixelSize.height > 0 else { return }
        let ratio = pixelSize.width / pixelSize.height
        let known = aspectRatios[page]
        aspectRatios[page] = ratio
        // The engine reports a page again when it decodes it larger; the shape is the same
        // and is saved once.
        if let known, sizedPages.contains(page), abs(known - ratio) <= known * 0.005 { return }
        sizedPages.insert(page)
        writer.add(GalleryPage(
            gid: gallery.gid, index: page,
            imageWidth: Int(pixelSize.width.rounded()), imageHeight: Int(pixelSize.height.rounded())
        ))
    }

    /// Downloading or decoding a page's image failed.
    public func imageDidFail(page: Int) {
        if staleCandidates.remove(page) != nil {
            // A URL from an earlier session: the site's image URLs expire. Resolve the page
            // again instead of showing a failure the user would have to tap away.
            resolver.resolveAgain(page)
        } else {
            failedImagePages.insert(page)
        }
    }

    /// The retry button of a page: an image that failed to load is fetched through another
    /// image server, a page that failed to resolve is resolved again.
    public func retry(page: Int) {
        if failedImagePages.remove(page) != nil {
            resolver.refetch(page)
        } else {
            resolver.retry(page)
        }
    }

    public func togglePanel() {
        showsPanel.toggle()
    }

    // MARK: Resolver events

    private func handle(_ event: ReaderPageResolver.Event) {
        switch event {
        case .resolved(let image):
            failedImagePages.remove(image.index)
            staleCandidates.remove(image.index)
            writer.add(GalleryPage(
                gid: gallery.gid, index: image.index,
                imageURL: image.imageURL, originalImageURL: image.originalImageURL
            ))
            engine?.reloadPage(image.index)
        case .failed(let page, _), .updated(let page):
            engine?.reloadPage(page)
        }
    }

    private func noteFirstPage() {
        guard timeToFirstPage == nil, let openedAt else { return }
        let elapsed = ContinuousClock.now - openedAt
        timeToFirstPage = elapsed
        let milliseconds = Int(elapsed / .milliseconds(1))
        // The timing only. The log files are in Documents, which the Files app shows: a line
        // that named the gallery would be a dated list of everything read.
        logger.info("First page shown after \(milliseconds) ms", category: "Reader")
    }
}
