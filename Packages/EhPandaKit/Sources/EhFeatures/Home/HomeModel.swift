import Dependencies
import EhCore
import EhModels
import EhNetworking
import Observation

/// The Home tab root: Popular cards, the Frontpage cover strip and the four Toplists columns.
///
/// Each section loads on its own, concurrently with the others, so one failing never blanks
/// the rest. The loads run in tasks the model owns: pushing a gallery while they are in flight
/// does not abandon them, and they are cancelled only when the model goes away. Reload requests
/// made while a section is already loading are ignored for that section, as in legacy.
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

    @ObservationIgnored private let tasks = ModelTasks()
    /// Sections with a load in flight. One task per section bounds the fan-out to six.
    @ObservationIgnored private var inFlight: Set<HomeSection> = []

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

    // MARK: Commands

    /// Loads the sections that have nothing to show and are not loading. Call it each time the
    /// screen appears.
    public func loadIfNeeded() {
        start(sectionsToLoadOnAppear)
    }

    /// Toolbar reload, Retry and re-selecting the Home tab: every section.
    public func reloadAll() {
        start(HomeSection.all)
    }

    /// Tapping the Frontpage header.
    public func reloadFrontpage() {
        start([.frontpage])
    }

    /// Tapping the Toplists header: all four periods.
    public func reloadToplists() {
        start(HomeSection.toplists)
    }

    /// Legacy loaded everything on appear when Popular was empty. Sections left empty by a
    /// failed load are loaded again too.
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

    private func start(_ sections: [HomeSection]) {
        for section in sections where inFlight.insert(section).inserted {
            setState(.loading, for: section)
            let fetch = fetch(section)
            tasks.run(section.taskKey) { [weak self] in
                let outcome = await Outcome.of { try await fetch() }
                self?.finish(section, with: outcome)
            }
        }
    }

    private func finish(_ section: HomeSection, with outcome: Outcome<[Gallery]>) {
        inFlight.remove(section)
        switch outcome {
        case .success(let galleries) where galleries.isEmpty:
            setState(.failed(.notFound), for: section)
        case .success(let galleries):
            apply(galleries, to: section)
            setState(.idle, for: section)
        case .failure(let error):
            setState(.failed(error), for: section)
        case .cancelled:
            setState(.idle, for: section)
        }
    }

    /// The request for `section`, holding the client and filter but not the model, so a load
    /// in flight does not keep a released model alive. Popular and Frontpage use the Global
    /// filter; Toplists take none.
    private func fetch(_ section: HomeSection) -> @Sendable () async throws -> [Gallery] {
        let client = client
        switch section {
        case .popular:
            let filter = filterStore.globalFilter
            return { try await client.popular(filter: filter) }
        case .frontpage:
            let filter = filterStore.globalFilter
            return { try await client.frontpage(filter: filter).galleries }
        case .toplists(let type):
            return { try await client.toplists(type: type).galleries }
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
