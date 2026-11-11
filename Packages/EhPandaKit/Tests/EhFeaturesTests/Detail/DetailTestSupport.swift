import Dependencies
import EhCore
import EhDatabase
import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Synchronization
import Testing

/// Everything a detail-feature model reads, faked: a stub transport serving fixtures, an
/// in-memory database, in-memory cookies, private preference stores and an immediate clock.
@MainActor
struct DetailEnvironment {
    static let gid = "2725078"
    static let token = "abcdef0123"
    static let galleryURL = URL(string: "https://e-hentai.org/g/2725078/abcdef0123/")!
    static let detailPath = "/g/2725078/abcdef0123/"

    let transport = StubTransport()
    let database: AppDatabase
    let cookies = CookieStore(storage: InMemoryCookieStorage())
    let settings = SettingsStore(defaults: DetailEnvironment.makeDefaults())
    let userStore = UserStore(defaults: DetailEnvironment.makeDefaults())
    let intents = DetailIntents()
    let clipboard = Recorder<String>()
    let openedURLs = Recorder<URL>()

    init() async throws {
        database = try await TestDatabase.inMemory()
        settings.galleryHost = .ehentai
    }

    var client: EhClient {
        EhClient(transport: transport, cookies: cookies, host: { .ehentai })
    }

    static let gallery = Gallery(
        gid: gid, token: token, title: "List title", rating: 4, tags: [], category: .nonH,
        uploader: "List uploader", pageCount: 156, postedDate: Date(timeIntervalSince1970: 0),
        coverURL: nil, galleryURL: galleryURL
    )

    /// Runs `body` with this environment's dependencies; models created inside keep them.
    func with<R>(_ body: () throws -> R) rethrows -> R {
        try withDependencies {
            $0.ehClient = client
            $0.cookieStore = cookies
            $0.database = database
            $0.settings = settings
            $0.userStore = userStore
            $0.continuousClock = InstantClock()
            $0.appLogger = .console(minimumLevel: .error)
            $0.clipboardClient = ClipboardClient(
                changeCount: { 0 }, url: { nil },
                copyText: { [clipboard] in clipboard.append($0) }, copyImage: { _ in }
            )
            $0.applicationClient = ApplicationClient(
                isPad: { false },
                openURL: { [openedURLs] in openedURLs.append($0); return true },
                openSettings: {}, alternateIconName: { nil }, setAlternateIconName: { _ in true },
                setOrientationLock: { _ in }
            )
        } operation: {
            try body()
        }
    }

    func makeDetailModel(gallery: Gallery = DetailEnvironment.gallery) -> GalleryDetailModel {
        with { GalleryDetailModel(gallery: gallery, intents: intents) }
    }

    /// A model that has loaded the detail fixture.
    func loadedDetailModel(fixture: String = "Parser/Gallery/GalleryDetail.html") async -> GalleryDetailModel {
        serveDetail(fixture: fixture)
        let model = makeDetailModel()
        await model.load()
        return model
    }

    func serveDetail(fixture: String = "Parser/Gallery/GalleryDetail.html") {
        transport.on(.method("GET") && .path(Self.detailPath), reply: .fixture(fixture))
    }

    /// Cookies of a logged-in E-Hentai member.
    func logIn(memberID: String = "1234567") {
        cookies.setOrEditCookie(for: GalleryHost.ehentai.url, name: "ipb_member_id", value: memberID)
        cookies.setOrEditCookie(for: GalleryHost.ehentai.url, name: "ipb_pass_hash", value: "hash")
    }

    /// Requests whose path is `path` and method `method`.
    func requests(_ method: String, path: String) -> [URLRequest] {
        transport.requests.filter {
            ($0.httpMethod ?? "GET") == method && $0.url?.path(percentEncoded: false) == path
        }
    }

    var detailFetchCount: Int {
        requests("GET", path: Self.detailPath).count
    }

    private static func makeDefaults() -> UserDefaults {
        let name = "DetailTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

/// A thread-safe list of values a fake dependency received.
final class Recorder<Value: Sendable>: Sendable {
    private let values = Mutex<[Value]>([])

    func append(_ value: Value) {
        values.withLock { $0.append(value) }
    }

    var all: [Value] {
        values.withLock { $0 }
    }
}

/// Waits until `condition` holds, failing the test after 20 s. Generous because the whole
/// suite runs in parallel on a busy machine.
@MainActor
func eventually(
    _ comment: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () async -> Bool
) async {
    let deadline = ContinuousClock.now.advanced(by: .seconds(20))
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(10))
    }
    Issue.record(comment ?? "Condition never became true", sourceLocation: sourceLocation)
}

/// A clock whose sleeps end at once. `ImmediateClock` yields through background-priority tasks,
/// which starve while the machine is busy; this one only checks for cancellation.
struct InstantClock: Clock {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    var now: Instant { Instant(offset: .zero) }
    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
    }
}

/// The JSON body of a request, for API calls.
func jsonBody(_ request: URLRequest) -> [String: Any] {
    guard let body = request.httpBody,
          let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    else { return [:] }
    return object
}

/// The form body of a request as a string.
func formBody(_ request: URLRequest) -> String {
    request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
}

/// A 200 response with a fixture's bytes, for `.handler` replies.
nonisolated func fixtureResponse(_ path: String, for request: URLRequest) throws -> HTTPResponse {
    let url = request.url ?? URL(string: "https://e-hentai.org/")!
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:])!
    return HTTPResponse(data: try Fixture.data(path), response: response)
}
