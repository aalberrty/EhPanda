import Dependencies
import EhCore
import EhModels
import EhNetworking
import Observation

/// The Home tab root: Popular cards, the Frontpage cover strip and the four Toplists columns.
///
/// Each section loads on its own, concurrently with the others, so one failing never blanks
/// the rest. Loading happens inside `run()`, which the view calls from `.task`: leaving the
/// screen cancels every request in flight. Reload requests made while a section is already
/// loading are ignored for that section, as in legacy.
@Observable
public final class HomeModel {
    public private(set) var cards: [Gallery] = []
    public private(set) var popularState: LoadingState = .idle

    /// De-duplicated frontpage galleries (at most 25).
    public private(set) var frontpage: [Gallery] = []
    public private(set) var frontpageState: LoadingState = .idle

    public private(set) var toplists: [ToplistsType: [Gallery]] = [:]
    public private(set) var toplistsStates: [ToplistsType: LoadingState] = [:]

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.filterStore) private var filterStore
    @ObservationIgnored @Dependency(\.withRandomNumberGenerator) private var withRandomNumberGenerator

    /// Reload requests for the current `run()`; `nil` while the screen is not running.
    @ObservationIgnored private var requests: AsyncStream<[HomeSection]>.Continuation?
    @ObservationIgnored private var runID = 0
    /// Sections with a load running in the current `run()`.
    @ObservationIgnored private var inFlight: Set<HomeSection> = []
    /// Bumped by every load, so a superseded load (from a cancelled run) never writes its result.
    @ObservationIgnored private var generations: [HomeSection: Int] = [:]

    public init() {}

    // MARK: Derived state

    public var coverColumns: [CoverColumn] {
        HomeSections.coverColumns(from: frontpage)
    }

    public var isLoadingToplists: Bool {
        toplistsStates.values.contains(.loading)
    }

    public func toplists(for type: ToplistsType) -> [Gallery] {
        toplists[type] ?? []
    }

    // MARK: Lifecycle

    /// Loads what is missing, then serves reload requests until the calling task is cancelled.
    ///
    /// The fan-out is bounded by construction: one task per section (six), and a section that
    /// is still loading is not started again.
    public func run() async {
        let (stream, continuation) = AsyncStream.makeStream(of: [HomeSection].self)
        runID += 1
        let id = runID
        requests = continuation
        // A previous run has been cancelled; its loads no longer count as in flight.
        inFlight.removeAll()
        defer {
            if runID == id { requests = nil }
        }

        continuation.yield(sectionsToLoadOnAppear)
        await withDiscardingTaskGroup { group in
            for await sections in stream {
                for section in sections where inFlight.insert(section).inserted {
                    group.addTask { await self.load(section) }
                }
            }
        }
    }

    /// Toolbar reload, Retry and re-selecting the Home tab: every section.
    public func reloadAll() {
        requests?.yield(HomeSection.all)
    }

    /// Tapping the Frontpage header.
    public func reloadFrontpage() {
        requests?.yield([.frontpage])
    }

    /// Tapping the Toplists header: all four periods.
    public func reloadToplists() {
        requests?.yield(HomeSection.toplists)
    }

    /// Legacy loaded everything on appear when Popular was empty. Sections left empty by a
    /// load cancelled when the screen went away are loaded again too.
    private var sectionsToLoadOnAppear: [HomeSection] {
        if cards.isEmpty { return HomeSection.all }
        var sections: [HomeSection] = []
        if frontpage.isEmpty { sections.append(.frontpage) }
        for type in ToplistsType.allCases where toplists(for: type).isEmpty {
            sections.append(.toplists(type))
        }
        return sections
    }

    // MARK: Loading

    private func load(_ section: HomeSection) async {
        let generation = generations[section, default: 0] + 1
        generations[section] = generation
        let isCurrent = { [unowned self] in generations[section] == generation }
        setState(.loading, for: section)
        defer {
            if isCurrent() { inFlight.remove(section) }
        }

        do {
            let galleries = try await fetch(section)
            guard isCurrent() else { return }
            guard !galleries.isEmpty else {
                setState(.failed(.notFound), for: section)
                return
            }
            apply(galleries, to: section)
            setState(.idle, for: section)
        } catch is CancellationError {
            if isCurrent() { setState(.idle, for: section) }
        } catch {
            if isCurrent() { setState(.failed(error as? AppError ?? .unknown), for: section) }
        }
    }

    /// Popular and Frontpage use the Global filter; Toplists take none.
    private func fetch(_ section: HomeSection) async throws -> [Gallery] {
        switch section {
        case .popular:
            try await client.popular(filter: filterStore.globalFilter)
        case .frontpage:
            try await client.frontpage(filter: filterStore.globalFilter).galleries
        case .toplists(let type):
            try await client.toplists(type: type).galleries
        }
    }

    private func apply(_ galleries: [Gallery], to section: HomeSection) {
        switch section {
        case .popular:
            cards = withRandomNumberGenerator { HomeSections.cards(from: galleries, using: &$0) }
        case .frontpage:
            frontpage = HomeSections.frontpage(from: galleries)
        case .toplists(let type):
            toplists[type] = galleries
        }
    }

    private func setState(_ state: LoadingState, for section: HomeSection) {
        switch section {
        case .popular:
            popularState = state
        case .frontpage:
            frontpageState = state
        case .toplists(let type):
            toplistsStates[type] = state
        }
    }
}
