import Dependencies
import EhCore
import EhDatabase
import EhModels
import EhNetworking
import EhParser
import Foundation
import Observation

/// The gallery detail screen: what is stored about the gallery, then the fresh page, and every
/// operation the screen offers (see `GalleryDetailModel+Operations`).
///
/// Content properties are assigned only when their value changes, so a section that reads one
/// of them is not re-rendered by a refresh that left it as it was.
@Observable
public final class GalleryDetailModel {
    public let gallery: Gallery

    // MARK: Content

    public private(set) var detail: GalleryDetail?
    public private(set) var tagRows: [DetailTagRow] = []
    /// The previews the detail page carried (or what is stored), by page.
    public private(set) var previews: [PreviewThumbnail] = []
    public private(set) var comments: [CommentItem] = []
    public private(set) var loadingState: LoadingState = .idle

    /// Every preview URL known so far, by 1-based page; the previews grid starts from these.
    @ObservationIgnored public private(set) var previewURLs: [Int: URL] = [:]
    @ObservationIgnored public private(set) var previewConfig: PreviewConfig?

    // MARK: Account

    /// Read from the cookies each time the screen appears, like legacy's live check.
    public private(set) var isLoggedIn = false
    /// The API key of the last fetched page, needed by ratings and votes.
    @ObservationIgnored public private(set) var apiKey = ""

    // MARK: Interaction

    /// The user's rating in half stars, 1...10, or 0 when the user has not rated.
    public var userRating = 0
    public internal(set) var showsRatingControl = false
    /// Counts submitted ratings, for the view's haptic.
    public internal(set) var ratingCommitCount = 0
    public var destination: DetailDestination?
    /// The last operation's result, for the view's haptic.
    public internal(set) var feedback: OperationFeedback?
    /// A New Dawn greeting the shell should announce; cleared with `greetingAnnounced()`.
    public private(set) var greetingToAnnounce: Greeting?

    // MARK: Plumbing

    @ObservationIgnored var tags: [GalleryTag] = []
    @ObservationIgnored var feedbackCounter = FeedbackCounter()
    @ObservationIgnored let tasks = ModelTasks()
    /// What the opener asked for; run once, after the first load.
    @ObservationIgnored private var pendingIntent: DetailIntent?
    @ObservationIgnored private var initialLoad: Task<Void, Never>?

    @ObservationIgnored @Dependency(\.ehClient) var client
    @ObservationIgnored @Dependency(\.database) var database
    @ObservationIgnored @Dependency(\.settings) var settings
    @ObservationIgnored @Dependency(\.userStore) var userStore
    @ObservationIgnored @Dependency(\.continuousClock) var clock
    @ObservationIgnored @Dependency(\.tagTranslationService) private var tagTranslations
    @ObservationIgnored @Dependency(\.appLogger) private var logger

    /// Cheap: nothing is read or fetched until `load()`.
    /// - Parameter intent: What to do once the screen has opened, e.g. open the reader at a page.
    public init(gallery: Gallery, intent: DetailIntent? = nil) {
        self.gallery = gallery
        pendingIntent = intent
    }

    // MARK: Derived

    /// The Japanese title when preferred and present, else the title. Before the page has
    /// loaded, the list's title.
    public func title(prefersJapanese: Bool) -> String {
        guard let detail else { return gallery.title }
        return prefersJapanese ? detail.jpnTitle ?? detail.title : detail.title
    }

    public var uploader: String? {
        detail?.uploader ?? gallery.uploader
    }

    public var pageCount: Int {
        detail?.pageCount ?? gallery.pageCount
    }

    /// Legacy disabled the toolbar menu until the page had loaded and while it reloaded.
    public var isMenuEnabled: Bool {
        detail != nil && !loadingState.isLoading
    }

    public var canOpenArchives: Bool {
        isLoggedIn && detail?.archiveURL != nil
    }

    public var torrentCount: Int {
        detail?.torrentCount ?? 0
    }

    /// The translation of a tag, by synchronous lookup in the translation service. Reading it
    /// observes the service, so chips update when the dictionary changes.
    public func translation(for chip: DetailTagChip) -> TagTranslationDisplay? {
        tagTranslations.display(forKey: chip.translationKey)
    }

    // MARK: Loading

    /// Shows what is stored, records the visit in the history, then fetches the page.
    ///
    /// Call from the view's `.task`. The work runs once per screen and outlives the call, so
    /// pushing a child (which ends the view's task) does not abandon a fetch halfway; later
    /// calls only refresh the login state and wait for that first load.
    public func load() async {
        isLoggedIn = client.cookies.didLogin
        if initialLoad == nil {
            if settings.translatesTags {
                // Reads the stored dictionary once per launch; later calls return at once.
                let tagTranslations = tagTranslations
                Task { await tagTranslations.load() }
            }
            initialLoad = tasks.run("load") { [weak self, database, gallery] in
                async let recorded: Void = GalleryDetailModel.recordOpened(gallery, in: database)
                let stored = await StoredDetail.read(gid: gallery.gid, from: database)
                await self?.applyStored(stored)
                self?.scheduleIntent()
                let fetch = self?.fetch()
                await fetch?.value
                await recorded
            }
        }
        await initialLoad?.value
    }

    /// Fetches the page again (Retry, and after every successful operation). Does nothing
    /// while a fetch is running.
    public func refetch() {
        fetch()
    }

    @discardableResult
    func fetch() -> Task<Void, Never>? {
        guard !loadingState.isLoading else { return nil }
        guard let galleryURL = gallery.galleryURL else {
            loadingState = .failed(.notFound)
            return nil
        }
        loadingState = .loading
        let client = client
        let gid = gallery.gid
        return tasks.run("fetch") { [weak self] in
            let outcome = await Outcome.of { try await client.galleryDetail(gid: gid, galleryURL: galleryURL) }
            await self?.finishFetch(outcome)
        }
    }

    private func finishFetch(_ outcome: Outcome<GalleryDetailResponse>) async {
        switch outcome {
        case .cancelled:
            loadingState = .idle
        case .failure(let error):
            loadingState = .failed(error)
        case .success(let response):
            apiKey = response.apiKey
            userStore.updateAPIKey(response.apiKey)
            setDetail(response.detail)
            previewConfig = response.state.previewConfig ?? previewConfig
            setPreviewURLs(response.state.previewURLs)
            loadingState = .idle
            persist(response)
            handleGreeting(response.greeting)
            setComments(await CommentItem.make(from: response.state.comments))
            await setTags(response.state.tags)
        }
    }

    private func applyStored(_ stored: StoredDetail) async {
        if let detail = stored.detail {
            setDetail(detail)
        }
        setPreviewURLs(stored.previewURLs)
        guard let state = stored.state else { return }
        previewConfig = state.previewConfig
        setComments(await CommentItem.make(from: state.comments))
        await setTags(state.tags)
    }

    // MARK: Assignments

    private func setDetail(_ newValue: GalleryDetail) {
        if detail != newValue {
            detail = newValue
        }
        let rating = Int((newValue.userRating * 2).rounded())
        if userRating != rating {
            userRating = rating
        }
    }

    private func setPreviewURLs(_ urls: [Int: URL]) {
        guard !urls.isEmpty || previewURLs.isEmpty else { return }
        previewURLs = urls
        let thumbnails = PreviewThumbnail.sorted(urls)
        if previews != thumbnails {
            previews = thumbnails
        }
    }

    private func setComments(_ items: [CommentItem]) {
        if comments != items {
            comments = items
        }
    }

    /// The rows carry each tag's translation detail, which needs Markdown rendering, so it is
    /// prepared once per tag list off the main actor instead of when a context menu opens.
    private func setTags(_ newTags: [GalleryTag]) async {
        tags = newTags
        let details = await tagTranslations.details(forKeys: DetailTagRow.translationKeys(of: newTags))
        // A newer list may have arrived meanwhile.
        guard tags == newTags else { return }
        let rows = DetailTagRow.rows(for: newTags, details: details)
        if tagRows != rows {
            tagRows = rows
        }
    }

    // MARK: Side effects

    /// Stores the fresh page through the database's focused updates. Not tied to the screen:
    /// what was fetched is kept even if the screen closes meanwhile.
    private func persist(_ response: GalleryDetailResponse) {
        let database = database
        let logger = logger
        let gid = gallery.gid
        let state = response.state
        let pages = state.previewURLs.map { GalleryPage(gid: gid, index: $0.key, previewURL: $0.value) }
        Task {
            do {
                try await database.saveDetail(response.detail)
                try await database.updateTags(gid: gid, tags: state.tags)
                try await database.updateComments(gid: gid, comments: state.comments)
                try await database.upsertPages(pages)
                if let config = state.previewConfig {
                    try await database.updatePreviewConfig(gid: gid, config: config)
                }
            } catch {
                logger.error("Could not store the detail of a gallery: \(error)", category: "Detail")
            }
        }
    }

    nonisolated private static func recordOpened(_ gallery: Gallery, in database: AppDatabase) async {
        try? await database.recordOpened(gallery)
    }

    /// Legacy stored every greeting and announced it when it brought something and the New Dawn
    /// setting was on.
    private func handleGreeting(_ greeting: Greeting?) {
        guard let greeting else { return }
        userStore.updateGreeting(greeting)
        if !greeting.gainedNothing && settings.showsNewDawnGreeting {
            greetingToAnnounce = greeting
        }
    }

    public func greetingAnnounced() {
        greetingToAnnounce = nil
    }

    /// Runs what the opener asked for, after the push animation (legacy waited 0.75 s).
    private func scheduleIntent() {
        guard let intent = pendingIntent else { return }
        pendingIntent = nil
        tasks.run("intent") { [weak self, clock] in
            try? await clock.sleep(for: .milliseconds(750))
            guard !Task.isCancelled, let self else { return }
            switch intent {
            case .read(let page):
                self.openReader(page: page)
            case .comments(let commentID):
                self.destination = .comments(scrollTo: commentID)
            }
        }
    }
}

/// What the database holds for one gallery.
nonisolated struct StoredDetail: Sendable {
    var detail: GalleryDetail?
    var state: GalleryState?
    var previewURLs: [Int: URL]

    static func read(gid: String, from database: AppDatabase) async -> StoredDetail {
        async let detail = database.detail(gid: gid)
        async let state = database.state(gid: gid)
        async let pages = database.pages(gid: gid)
        var previewURLs = [Int: URL]()
        for page in (try? await pages) ?? [] {
            previewURLs[page.index] = page.previewURL
        }
        return StoredDetail(
            detail: (try? await detail) ?? nil, state: (try? await state) ?? nil, previewURLs: previewURLs
        )
    }
}
