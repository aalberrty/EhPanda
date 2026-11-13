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
    /// Counts the fetched pages that were applied. What is prepared off the main actor for a
    /// page (or for what is stored, which is older than any page) is dropped when a newer
    /// page has been applied meanwhile.
    @ObservationIgnored private var appliedFetches = 0

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

    public var isFavorited: Bool {
        detail?.isFavorited == true
    }

    /// Legacy offered "Show all" previews only past the 20 the detail page carries.
    public var showsAllPreviews: Bool {
        pageCount > 20
    }

    /// The search "Similar gallery" opens, once the page has loaded.
    public var similarGalleryKeyword: String? {
        detail.map(DetailSearchKeyword.similar(to:))
    }

    /// The translation of a tag, by synchronous lookup in the translation service. Reading it
    /// observes the service, so chips update when the dictionary changes.
    public func translation(for chip: DetailTagChip) -> TagTranslationDisplay? {
        tagTranslations.display(forKey: chip.translationKey)
    }

    // MARK: Loading

    /// Fetches the page, and meanwhile shows what is stored and records the visit in the
    /// history. The request goes out first: preparing stored comments and tags takes tens of
    /// milliseconds that the network round trip does not have to wait for.
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
                let fetch = self?.fetch()
                let stored = await StoredDetail.read(gid: gallery.gid, from: database)
                await self?.applyStored(stored)
                self?.scheduleIntent()
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
            appliedFetches += 1
            let fetch = appliedFetches
            apiKey = response.apiKey
            userStore.updateAPIKey(response.apiKey)
            setDetail(response.detail)
            previewConfig = response.state.previewConfig ?? previewConfig
            setPreviewURLs(response.previewPage.previewURLs)
            loadingState = .idle
            let saved = persist(response)
            handleGreeting(response.greeting)
            let comments = await CommentItem.make(from: response.state.comments)
            // The page was fetched again meanwhile (after a vote, say) and that page's
            // comments may already be in place.
            if fetch == appliedFetches {
                setComments(comments)
            }
            await setTags(response.state.tags)
            // The reader and the previews grid start from what is stored, so a load that has
            // returned has stored it.
            await saved.value
        }
    }

    /// Shows what the database holds until the page arrives. If the page got here first, what
    /// is stored is older and is not applied.
    private func applyStored(_ stored: StoredDetail) async {
        guard appliedFetches == 0 else { return }
        if let detail = stored.detail {
            setDetail(detail)
        }
        setPreviewURLs(stored.previewURLs)
        guard let state = stored.state else { return }
        previewConfig = state.previewConfig
        let comments = await CommentItem.make(from: state.comments)
        guard appliedFetches == 0 else { return }
        setComments(comments)
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

    /// Stores the fresh page in one transaction. Not tied to the screen: what was fetched is
    /// kept even if the screen closes meanwhile.
    ///
    /// The detail page is the gallery's first preview page, so its pages are stored with their
    /// viewer links as well as their thumbnails: the reader then starts at the viewer page
    /// instead of fetching this page again for the links.
    private func persist(_ response: GalleryDetailResponse) -> Task<Void, Never> {
        let database = database
        let logger = logger
        return Task {
            do {
                try await database.saveDetail(response.detail, state: response.state)
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
