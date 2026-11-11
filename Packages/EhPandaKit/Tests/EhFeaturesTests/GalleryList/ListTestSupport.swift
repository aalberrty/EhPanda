import Dependencies
import EhCore
import EhDatabase
import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Synchronization

/// Dependencies for list tests: a client on a `StubTransport`, its own cookies (logged in unless
/// asked otherwise), its own filter store and an in-memory database.
@MainActor
final class ListTestEnvironment {
    let transport = StubTransport()
    let cookies = CookieStore(storage: InMemoryCookieStorage())
    let filterStore = FilterStore(defaults: UserDefaults(suiteName: "ListTests-\(UUID().uuidString)")!)
    let database: AppDatabase

    init(loggedIn: Bool = true) throws {
        database = try AppDatabase.makeInMemory()
        if loggedIn { logIn() }
    }

    func logIn() {
        cookies.setOrEditCookie(for: GalleryHost.ehentai.url, name: CookieName.ipbMemberId, value: "1")
        cookies.setOrEditCookie(for: GalleryHost.ehentai.url, name: CookieName.ipbPassHash, value: "hash")
    }

    /// Builds a model with these dependencies; its `@Dependency` properties keep them.
    func make<Model>(_ build: () -> Model) -> Model {
        withDependencies {
            $0.ehClient = EhClient(transport: transport, cookies: cookies, host: { .ehentai })
            $0.cookieStore = cookies
            $0.filterStore = filterStore
            $0.database = database
        } operation: {
            build()
        }
    }

    /// Query value `name` of request `index`.
    func query(_ name: String, ofRequest index: Int) -> String? {
        let requests = transport.requests
        guard requests.indices.contains(index), let url = requests[index].url else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == name }?.value
    }
}

nonisolated enum ListFixture {
    static let frontpage = "Parser/List/FrontPageCompactList.html"
    static let watched = "Parser/List/WatchedCompactList.html"
    static let favorites = "Parser/List/FavoritesCompactList.html"
    static let popular = "Parser/List/PopularCompactList.html"
    static let toplists = "Parser/List/ToplistsCompactList.html"

    /// The `next` cursor of the frontpage fixture (its last gallery).
    static let frontpageLastID = "2668517"
    static let watchedLastID = "2592671"
    static let favoritesLastID = "1452536"
    static let favoritesLastTimestamp = "1610434311"

    /// A page without galleries whose "Next" link continues after `nextID`.
    static func emptyPage(nextID: String) -> StubTransport.Reply {
        .html("""
        <html><body><div class="searchnav">\
        <a href="https://e-hentai.org/?next=\(nextID)">Next &gt;</a></div></body></html>
        """)
    }

    /// The favorites fixture with the sort-order toggle the site shows above the list
    /// ("Use Posted" while sorted by favorited time).
    static func favoritesSorted(by order: FavoritesSortOrder) throws -> StubTransport.Reply {
        let toggle = order == .favoritedTime ? "Use Posted" : "Use Favorited"
        let html = try Fixture.string(favorites).replacingOccurrences(
            of: "<body>", with: "<body><div class='ido'><div><div><a href='#'>\(toggle)</a></div></div></div>"
        )
        return .html(html)
    }

    /// A page without galleries and without a next page.
    static let lastEmptyPage = StubTransport.Reply.html("<html><body></body></html>")
}

extension Gallery {
    static func stub(_ gid: String, title: String = "Title", lastOpenDate: Date? = nil) -> Gallery {
        Gallery(
            gid: gid, token: "t\(gid)", title: title, rating: 4, tags: [], category: .doujinshi,
            uploader: nil, pageCount: 1, postedDate: Date(timeIntervalSince1970: 0),
            coverURL: nil, galleryURL: nil, lastOpenDate: lastOpenDate
        )
    }
}

/// Lets other tasks on the main actor run until `condition` holds (or gives up).
@MainActor
func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<1000 where !condition() {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(1))
    }
}

/// Stands in for `PagedGalleryList`'s `.task(id: model.loadTrigger) { await model.loadIfNeeded() }`:
/// like SwiftUI, it runs the load when first rendered and again only when the id changed. Tests
/// that switch lists render through it instead of calling `loadIfNeeded()`, so a switch the view
/// would not notice leaves the new list unloaded here too.
@MainActor
struct ListScreenTask {
    private var lastTrigger: GalleryListModel.LoadTrigger?

    /// Renders `list` and awaits the load its task would start, if any.
    mutating func render(_ list: GalleryListModel) async {
        let trigger = list.loadTrigger
        guard trigger != lastTrigger else { return }
        lastTrigger = trigger
        await list.loadIfNeeded()
    }
}

/// A flag a stubbed reply can wait on, so a test decides when a response arrives.
nonisolated final class Gate: Sendable {
    private let state = Mutex(false)

    var isOpen: Bool { state.withLock { $0 } }

    func open() { state.withLock { $0 = true } }

    func wait() async {
        while !isOpen, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(2)) }
    }
}

extension Fixture {
    /// A 200 response to `request` whose body is the fixture at `path`.
    nonisolated static func response(_ path: String, for request: URLRequest) throws -> HTTPResponse {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else { throw URLError(.badURL) }
        return HTTPResponse(data: try Fixture.data(path), response: response)
    }
}
