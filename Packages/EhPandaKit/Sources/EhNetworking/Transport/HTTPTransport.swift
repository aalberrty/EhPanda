import Foundation
import os

/// The single seam every request goes through. Tests substitute a stub; the app uses
/// `URLSessionTransport`, usually wrapped in a `RetryingTransport`.
///
/// Contract:
/// - Non-2xx statuses are returned, not thrown: the site reports most errors inside 200 pages,
///   so interpreting a status is the caller's job.
/// - Transport-level failures throw `URLError`.
/// - Cancelling the calling task cancels the underlying request, which then throws
///   `URLError(.cancelled)`.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

public struct HTTPResponse: Sendable {
    public let data: Data
    public let response: HTTPURLResponse

    public init(data: Data, response: HTTPURLResponse) {
        self.data = data
        self.response = response
    }

    public var statusCode: Int { response.statusCode }
}

enum NetworkLog {
    static let logger = Logger(subsystem: "app.ehpanda", category: "network")
}

extension URLError {
    /// Wraps any error as a `URLError`, keeping the original as the underlying error.
    /// Cancellation of the current task always becomes `.cancelled`.
    static func normalized(_ error: any Error) -> URLError {
        if let urlError = error as? URLError { return urlError }
        if error is CancellationError || Task.isCancelled { return URLError(.cancelled) }
        return URLError(.unknown, userInfo: [NSUnderlyingErrorKey: error])
    }
}
