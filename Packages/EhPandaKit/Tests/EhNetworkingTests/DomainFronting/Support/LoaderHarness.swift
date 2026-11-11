import EhTestSupport
import Foundation
import Synchronization
@testable import EhNetworking

/// Everything a finished load reported.
struct LoadOutcome {
    var events: [DFLoadEvent]

    var response: HTTPURLResponse? {
        events.lazy.compactMap { if case .received(let response) = $0 { response } else { nil } }.first
    }

    var body: Data {
        events.reduce(into: Data()) { body, event in
            if case .loaded(let data) = event { body.append(data) }
        }
    }

    var redirect: (request: URLRequest, response: HTTPURLResponse)? {
        for case .redirected(let request, let response) in events {
            return (request, response)
        }
        return nil
    }

    var error: URLError? {
        events.lazy.compactMap { if case .failed(let error) = $0 { error } else { nil } }.first
    }

    var didFinish: Bool {
        events.contains { if case .finished = $0 { true } else { false } }
    }
}

/// Collects what a load reports while a test does something else.
final class EventLog: Sendable {
    private let events = Mutex<[DFLoadEvent]>([])

    var all: [DFLoadEvent] { events.withLock { $0 } }

    func append(_ event: DFLoadEvent) {
        events.withLock { $0.append(event) }
    }
}

extension DFLoadEvent {
    /// Whether nothing follows this event.
    var endsLoad: Bool {
        switch self {
        case .redirected, .finished, .failed: true
        case .received, .loaded: false
        }
    }
}

extension DFLoader {
    /// A loader that finds every fronted domain on this machine, where a `LocalServer` listens
    /// on the port the request's URL names.
    static func local(
        cookieStorage: HTTPCookieStorage = InMemoryCookieStorage(),
        evaluateTrust: @escaping EvaluateTrust = TestCertificates.trustingTestRoot
    ) -> DFLoader {
        DFLoader(
            resolve: { ResolvableDomain(rawValue: $0) == nil ? nil : "127.0.0.1" },
            cookieStorage: cookieStorage,
            evaluateTrust: evaluateTrust
        )
    }

    /// Runs a load to its end.
    func outcome(of request: URLRequest) async -> LoadOutcome {
        let (events, continuation) = AsyncStream.makeStream(of: DFLoadEvent.self)
        _ = load(request) { event in
            continuation.yield(event)
            if event.endsLoad { continuation.finish() }
        }
        var outcome = LoadOutcome(events: [])
        for await event in events {
            outcome.events.append(event)
        }
        return outcome
    }
}

extension LocalServer {
    /// A URL for `domain` that reaches this server once the domain resolves to this machine.
    func url(_ path: String = "/", domain: String = "e-hentai.org") -> URL {
        URL(string: "https://\(domain):\(port)\(path)")!
    }

    /// Waits for every connection the server accepted to end, so the record is final.
    func connectionsDidEnd() async -> Bool {
        await eventually { record.connections > 0 && record.closed == record.connections }
    }
}

func makeCookie(_ name: String, _ value: String, domain: String = "e-hentai.org", path: String = "/") -> HTTPCookie {
    HTTPCookie(properties: [.name: name, .value: value, .domain: domain, .path: path])!
}

/// A login as the app sends it: the password in the body, alongside the session's cookies.
func makeLoginRequest(_ url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = Data("UserName=me&PassWord=SECRET-PASSWORD".utf8)
    return request
}
