import EhNetworking
import Foundation
import Synchronization

/// An `HTTPTransport` that answers from registered routes instead of the network.
///
/// ```swift
/// let transport = StubTransport()
/// transport.on(.path("/g/1/abc/"), reply: .fixture("Parser/Detail/Gallery.html"))
/// transport.on(.method("POST") && .host("e-hentai.org"),
///              replies: .error(URLError(.timedOut)), .status(200))
/// ```
///
/// - The most recently registered matching route answers, so a test can override a default.
/// - A route with several replies uses them in order and then keeps repeating the last one.
/// - Every request is recorded in `requests`, including unmatched ones, which throw
///   `StubTransport.Unmatched`.
public final class StubTransport: HTTPTransport {
    private struct Route {
        let matcher: Matcher
        var replies: [Reply]
    }

    private struct State {
        var routes: [Route] = []
        var requests: [URLRequest] = []
    }

    private let state = Mutex(State())

    public init() {}

    /// Requests received so far, in order.
    public var requests: [URLRequest] {
        state.withLock { $0.requests }
    }

    public func on(_ matcher: Matcher, reply: Reply) {
        on(matcher, replies: [reply])
    }

    public func on(_ matcher: Matcher, replies: Reply...) {
        on(matcher, replies: replies)
    }

    public func on(_ matcher: Matcher, replies: [Reply]) {
        precondition(!replies.isEmpty, "A route needs at least one reply")
        state.withLock { $0.routes.append(Route(matcher: matcher, replies: replies)) }
    }

    /// Forgets all routes and recorded requests.
    public func reset() {
        state.withLock { $0 = State() }
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let reply = state.withLock { state -> Reply? in
            state.requests.append(request)
            guard let index = state.routes.lastIndex(where: { $0.matcher.matches(request) }) else { return nil }
            let replies = state.routes[index].replies
            if replies.count > 1 {
                state.routes[index].replies.removeFirst()
            }
            return replies[0]
        }
        guard let reply else { throw Unmatched(request: request) }
        return try await reply.resolve(for: request)
    }

    public struct Unmatched: Error, CustomStringConvertible {
        public let request: URLRequest
        public var description: String {
            "StubTransport has no route for \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "nil")"
        }
    }
}

// MARK: Matcher

extension StubTransport {
    /// A predicate on the request. Combine with `&&`.
    public struct Matcher: Sendable {
        public let matches: @Sendable (URLRequest) -> Bool

        public init(_ matches: @escaping @Sendable (URLRequest) -> Bool) {
            self.matches = matches
        }

        public static let any = Matcher { _ in true }

        /// The exact, decoded path, trailing slash included.
        public static func path(_ path: String) -> Matcher {
            Matcher { $0.url?.path(percentEncoded: false) == path }
        }

        public static func host(_ host: String) -> Matcher {
            Matcher { $0.url?.host == host }
        }

        /// Case-insensitive; a request without a method is a `GET`.
        public static func method(_ method: String) -> Matcher {
            Matcher { ($0.httpMethod ?? "GET").uppercased() == method.uppercased() }
        }

        /// The query has an item `name`, and when `value` is given, with that value.
        public static func query(_ name: String, _ value: String? = nil) -> Matcher {
            Matcher { request in
                guard let url = request.url,
                      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                else { return false }
                return items.contains { $0.name == name && (value == nil || $0.value == value) }
            }
        }

        public static func url(_ url: URL) -> Matcher {
            Matcher { $0.url == url }
        }

        public static func && (lhs: Matcher, rhs: Matcher) -> Matcher {
            Matcher { lhs.matches($0) && rhs.matches($0) }
        }
    }
}

// MARK: Reply

extension StubTransport {
    public enum Reply: Sendable {
        /// A response with the given status, headers and body.
        case response(status: Int = 200, headers: [String: String] = [:], body: Data = Data())
        /// A response whose body is a file under `Fixtures`, loaded when the request arrives.
        case fixture(String, status: Int = 200, headers: [String: String] = [:])
        /// Throws the error.
        case error(any Error)
        /// Waits until the calling task is cancelled, then throws `URLError(.cancelled)`.
        case suspendUntilCancelled
        /// Computes the response, for anything the other cases cannot express.
        case handler(@Sendable (URLRequest) async throws -> HTTPResponse)

        public static func status(_ status: Int, headers: [String: String] = [:]) -> Reply {
            .response(status: status, headers: headers, body: Data())
        }

        public static func body(_ body: Data, status: Int = 200, headers: [String: String] = [:]) -> Reply {
            .response(status: status, headers: headers, body: body)
        }

        public static func html(_ html: String, status: Int = 200, headers: [String: String] = [:]) -> Reply {
            .response(status: status, headers: headers, body: Data(html.utf8))
        }

        func resolve(for request: URLRequest) async throws -> HTTPResponse {
            switch self {
            case let .response(status, headers, body):
                return try Self.make(request, status: status, headers: headers, body: body)
            case let .fixture(path, status, headers):
                return try Self.make(request, status: status, headers: headers, body: Fixture.data(path))
            case let .error(error):
                throw error
            case .suspendUntilCancelled:
                do {
                    while true { try await Task.sleep(for: .seconds(3600)) }
                } catch {
                    throw URLError(.cancelled)
                }
            case let .handler(handler):
                return try await handler(request)
            }
        }

        private static func make(
            _ request: URLRequest, status: Int, headers: [String: String], body: Data
        ) throws -> HTTPResponse {
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)
            else { throw URLError(.badURL) }
            return HTTPResponse(data: body, response: response)
        }
    }
}
