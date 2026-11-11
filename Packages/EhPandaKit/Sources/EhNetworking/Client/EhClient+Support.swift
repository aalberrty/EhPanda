import EhModels
import EhParser
import Foundation

// Plumbing shared by every operation.
//
// Kanna documents are not `Sendable`, so operations create each document right after the
// last `await` that produced its bytes and finish parsing it before any further `await`.
// No helper here takes or returns a document, which keeps that rule visible at each call site
// (and keeps `EhNetworking` from importing Kanna, which only `EhParser` depends on).
extension EhClient {
    /// Runs one operation: reads the host once, hands the body a builder for it, and maps
    /// every failure through `EhClientError.map`.
    func perform<T>(_ body: (EhRequestBuilder) async throws -> T) async throws -> T {
        do {
            return try await body(EhRequestBuilder(host: host()))
        } catch {
            throw EhClientError.map(error)
        }
    }

    /// Sends a request. Statuses are not checked: the site reports errors inside its pages,
    /// and legacy parsed every body whatever the status.
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        try await transport.send(request)
    }

    func body(_ request: URLRequest) async throws -> Data {
        try await transport.send(request).data
    }

    /// Sends a request whose response legacy ignored (favourites, ratings, comments, votes).
    /// Only transport failures surface.
    func fire(_ request: URLRequest) async throws {
        _ = try await transport.send(request)
    }

    /// The member id for API calls, which take it as a number.
    func memberID(for host: GalleryHost) throws -> Int {
        try number(cookies.memberID(for: host))
    }
}

/// Converts an id the API sends as a number. Legacy callers skipped the operation when this
/// failed (no login, malformed gid); the client reports it instead of pretending success.
func number(_ string: String) throws -> Int {
    guard let value = Int(string) else { throw AppError.unknown }
    return value
}

/// The one place that turns failures into the client's error contract.
enum EhClientError {
    /// | Failure | Result |
    /// |---|---|
    /// | the calling task is cancelled, `CancellationError` | `CancellationError` |
    /// | `URLError.cancelled` | `CancellationError` |
    /// | any other `URLError` | `AppError.networkingFailed` |
    /// | `AppError` (parser, client) | unchanged |
    /// | `DecodingError` | `AppError.parseFailed` |
    /// | anything else | `AppError.unknown` |
    static func map(_ error: any Error) -> any Error {
        if error is CancellationError || Task.isCancelled {
            return CancellationError()
        }
        switch error {
        case let appError as AppError:
            return appError
        case let urlError as URLError:
            return urlError.code == .cancelled ? CancellationError() : AppError.networkingFailed
        case is DecodingError:
            return AppError.parseFailed
        default:
            return AppError.unknown
        }
    }
}
