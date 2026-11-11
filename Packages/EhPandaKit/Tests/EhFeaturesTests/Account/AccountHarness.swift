import Dependencies
@testable import EhCore
import EhDatabase
@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Synchronization

/// One isolated account environment: stubbed transport, in-memory cookies, stores and
/// database, and a session wired to all of them. Models made with `make` share them.
@MainActor final class AccountHarness {
    let transport = StubTransport()
    let storage = InMemoryCookieStorage()
    let settings = SettingsStore(storage: .ephemeral())
    let user = UserStore(storage: .ephemeral())
    let database: AppDatabase
    let copiedTexts = Recorder<String>()
    let diskCacheClears = Recorder<Void>()
    private(set) var session: AccountSession!

    var cookies: CookieStore { CookieStore(storage: storage) }

    init() async throws {
        database = try await TestDatabase.inMemory()
        session = make { AccountSession() }
    }

    func make<Model>(_ build: () -> Model) -> Model {
        withDependencies { values in
            values.cookieStore = cookies
            values.ehClient = EhClient(
                transport: transport, cookies: cookies, host: settings.galleryHostProvider.currentHost
            )
            values.settings = settings
            values.userStore = user
            values.database = database
            values.imageCacheClient = ImageCacheClient(
                diskCacheSize: { 0 },
                clearDiskCache: { [diskCacheClears] in diskCacheClears.record(()) },
                imageData: { _ in Data() }
            )
            values.clipboardClient = ClipboardClient(
                changeCount: { 0 }, url: { nil },
                copyText: { [copiedTexts] in copiedTexts.record($0) },
                copyImage: { _ in }
            )
            if let session {
                values.accountSession = session
            }
        } operation: {
            build()
        }
    }

    // MARK: Cookies

    func setLogin(on host: GalleryHost, memberID: String = "123", passHash: String = "hash", igneous: String? = nil) {
        for url in host.cookieURLs {
            cookies.setOrEditCookie(for: url, name: CookieName.ipbMemberId, value: memberID)
            cookies.setOrEditCookie(for: url, name: CookieName.ipbPassHash, value: passHash)
            if let igneous {
                cookies.setOrEditCookie(for: url, name: CookieName.igneous, value: igneous)
            }
        }
    }

    func setExpiredCookie(_ name: String, on host: GalleryHost) {
        let properties: [HTTPCookiePropertyKey: Any] = [
            .path: "/", .name: name, .value: "old", .originURL: host.url,
            .expires: Date(timeIntervalSinceNow: -60)
        ]
        if let cookie = HTTPCookie(properties: properties) {
            storage.setCookie(cookie)
        }
    }

    func cookie(_ name: String, _ url: URL) -> String {
        cookies.cookie(named: name, for: url).rawValue
    }

    // MARK: Requests

    func requests(_ method: String, path: String) -> [URLRequest] {
        transport.requests.filter {
            ($0.httpMethod ?? "GET") == method && $0.url?.path(percentEncoded: false) == path
        }
    }

    static func body(of request: URLRequest) -> String {
        request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}

// MARK: Stubs

extension StubTransport.Matcher {
    static let settingsPage = StubTransport.Matcher.method("GET") && .path("/uconfig.php")
    static let settingsPost = StubTransport.Matcher.method("POST") && .path("/uconfig.php")
    static let login = StubTransport.Matcher.method("POST") && .host("forums.e-hentai.org")
    static let igneous = StubTransport.Matcher.method("GET") && .host("exhentai.org") && .path("/")
}

enum AccountFixture {
    static let settingsPath = "Parser/Other/EhSetting.html"

    /// The settings page; its profiles are Default Profile (1, selected), EhPanda (2) and
    /// FEhViewer (3).
    static var settings: StubTransport.Reply { .fixture(settingsPath) }

    /// The settings page without an "EhPanda" profile.
    static func settingsWithoutEhPandaProfile() throws -> StubTransport.Reply {
        .html(try Fixture.string(settingsPath).replacingOccurrences(of: ">EhPanda<", with: ">Mobile<"))
    }

    static func setCookie(_ header: String) -> StubTransport.Reply {
        .status(200, headers: ["Set-Cookie": header])
    }

    static let loginCookies = setCookie(
        "ipb_member_id=42; path=/; domain=.e-hentai.org, ipb_pass_hash=secret; path=/; domain=.e-hentai.org"
    )
}

/// Collects values from `@Sendable` closures.
nonisolated final class Recorder<Value: Sendable>: Sendable {
    private let values = Mutex<[Value]>([])

    func record(_ value: Value) {
        values.withLock { $0.append(value) }
    }

    var all: [Value] { values.withLock { $0 } }
    var count: Int { all.count }
}
