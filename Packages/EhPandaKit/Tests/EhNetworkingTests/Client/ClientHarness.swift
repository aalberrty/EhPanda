import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Synchronization
import Testing

/// A client on a `StubTransport` and an in-memory cookie jar, with a host tests can switch.
struct ClientHarness {
    let transport = StubTransport()
    let storage = InMemoryCookieStorage()
    private let selectedHost: HostBox

    init(host: GalleryHost = .ehentai) {
        selectedHost = HostBox(host)
    }

    var client: EhClient {
        EhClient(transport: transport, cookies: cookies, host: { [selectedHost] in selectedHost.value })
    }

    var cookies: CookieStore { CookieStore(storage: storage) }

    var host: GalleryHost {
        get { selectedHost.value }
        nonmutating set { selectedHost.value = newValue }
    }

    var builder: EhRequestBuilder { EhRequestBuilder(host: host) }

    var requests: [URLRequest] { transport.requests }

    /// The one request the operation sent.
    func onlyRequest(sourceLocation: SourceLocation = #_sourceLocation) throws -> URLRequest {
        let requests = transport.requests
        #expect(requests.count == 1, sourceLocation: sourceLocation)
        return try #require(requests.last, sourceLocation: sourceLocation)
    }

    /// Stores a login (member id and pass hash) for `host`.
    func logIn(memberID: String = "12345", host: GalleryHost = .ehentai) {
        cookies.setOrEditCookie(for: host.url, name: "ipb_member_id", value: memberID)
        cookies.setOrEditCookie(for: host.url, name: "ipb_pass_hash", value: "hash")
    }
}

private final class HostBox: Sendable {
    private let host: Mutex<GalleryHost>

    init(_ host: GalleryHost) {
        self.host = Mutex(host)
    }

    var value: GalleryHost {
        get { host.withLock { $0 } }
        set { host.withLock { $0 = newValue } }
    }
}

/// Fixture paths, relative to `Fixtures/`.
enum ClientFixture {
    static let detail = "Parser/Gallery/GalleryDetail.html"
    static let detailWithGreeting = "Parser/Other/GalleryDetailWithGreeting.html"
    static let imagePage = "Parser/Gallery/GalleryNormalImageURL.html"
    static let mpvKeys = "Parser/Gallery/GalleryMPVKeys.html"
    static let ehSetting = "Parser/Other/EhSetting.html"
    static let ipBanned = "Parser/Other/IPBanned.html"

    static func list(_ name: String) -> String { "Parser/List/\(name).html" }
}

func clientURL(_ string: String) -> URL {
    guard let url = URL(string: string) else {
        Issue.record("Invalid test URL \(string)")
        return URL(fileURLWithPath: "/")
    }
    return url
}

/// The request's method and absolute URL, e.g. `"GET https://e-hentai.org/"`.
func line(_ request: URLRequest) -> String {
    "\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "nil")"
}

func jsonBody(_ request: URLRequest) throws -> [String: Any] {
    let data = try #require(request.httpBody)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

/// The error an operation threw, or `nil` when it succeeded.
func thrownError<T>(_ operation: () async throws -> T) async -> (any Error)? {
    do {
        _ = try await operation()
        return nil
    } catch {
        return error
    }
}
