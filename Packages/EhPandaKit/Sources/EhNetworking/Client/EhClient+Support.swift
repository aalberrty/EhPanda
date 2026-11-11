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
    /// every failure through `EhClientError.resolve`, which explains a body that failed to
    /// parse by the response the operation last received (`OperationTrace`). Failures decided
    /// by the server's answer are reported to `onFailure`, once per operation.
    func perform<T>(
        function: String = #function, _ body: (EhRequestBuilder) async throws -> T
    ) async throws -> T {
        let builder = EhRequestBuilder(host: host())
        let trace = OperationTrace()
        do {
            return try await OperationTrace.$current.withValue(trace) {
                try await body(builder)
            }
        } catch {
            let resolution = EhClientError.resolve(error, trace: trace)
            if let failure = resolution.failure(operation: function, trace: trace) {
                onFailure(failure)
            }
            throw resolution.error
        }
    }

    /// Sends a request and records it in the operation's trace. Statuses are not checked
    /// here: the site reports most errors inside its pages, and legacy parsed every body
    /// whatever the status. A status only explains a body that then fails to parse.
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let trace = OperationTrace.current
        trace?.willSend(request)
        let response = try await transport.send(request)
        trace?.didReceive(response, for: request)
        return response
    }

    /// The body of a response that should be a page (HTML or API JSON). Throws the specific
    /// error for an answer that can never be one (a refused ExHentai session, a login prompt)
    /// before any parser can mistake it for an empty page.
    func body(_ request: URLRequest) async throws -> Data {
        let response = try await send(request)
        let snapshot = ResponseSnapshot(request: request, response: response)
        if let error = ResponseClassifier.classifyBeforeParsing(snapshot) {
            throw error
        }
        return response.data
    }

    /// Sends a request whose response legacy ignored (favourites, ratings, comments, votes).
    /// Only transport failures surface.
    func fire(_ request: URLRequest) async throws {
        _ = try await send(request)
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
    /// The client's error for a failure, and how it was decided when the server's answer
    /// decided it.
    struct Resolution {
        var error: any Error
        /// Set for failures that come from what the server sent, which are worth a log line.
        var reason: String?

        func failure(operation: String, trace: OperationTrace) -> EhClientFailure? {
            guard let reason, let appError = error as? AppError else { return nil }
            return EhClientFailure(
                operation: operation, error: appError, reason: reason,
                request: trace.lastRequest, response: trace.lastResponse
            )
        }
    }

    /// | Failure | Result |
    /// |---|---|
    /// | the calling task is cancelled, `CancellationError` | `CancellationError` |
    /// | `URLError.cancelled` | `CancellationError` |
    /// | `URLError.httpTooManyRedirects` from exhentai.org | `AppError.exhentaiAccessDenied` |
    /// | any other `URLError` | `AppError.networkingFailed` |
    /// | `AppError.parseFailed` or `DecodingError` | the last response's classification, \* |
    /// | `AppError` from `body` (refused session, login prompt) | unchanged |
    /// | any other `AppError` (parser, client) | unchanged |
    /// | anything else | `AppError.unknown` |
    ///
    /// \* `ResponseClassifier.classifyParseFailure`: `.exhentaiAccessDenied`, `.loginRequired`,
    /// `.ipBanned`, or `.serverError` for a 4xx or 5xx status; `.parseFailed` when nothing is
    /// recognised or no response was received.
    static func resolve(_ error: any Error, trace: OperationTrace?) -> Resolution {
        if error is CancellationError || Task.isCancelled {
            return Resolution(error: CancellationError())
        }
        switch error {
        case let urlError as URLError:
            return resolve(urlError, trace: trace)
        case AppError.parseFailed, is DecodingError:
            guard let response = trace?.lastResponse else {
                return Resolution(error: AppError.parseFailed, reason: "parse failure without a response")
            }
            if let classified = ResponseClassifier.classifyParseFailure(response) {
                return Resolution(error: classified, reason: "classified from a parse failure")
            }
            return Resolution(error: AppError.parseFailed, reason: "unrecognised response")
        case let appError as AppError:
            return Resolution(error: appError, reason: reason(recognising: appError))
        default:
            return Resolution(error: AppError.unknown)
        }
    }

    private static func resolve(_ error: URLError, trace: OperationTrace?) -> Resolution {
        switch error.code {
        case .cancelled:
            Resolution(error: CancellationError())
        case .httpTooManyRedirects where trace?.lastRequest?.host == ResponseClassifier.exhentaiHost:
            Resolution(error: AppError.exhentaiAccessDenied, reason: "redirect loop")
        default:
            Resolution(error: AppError.networkingFailed)
        }
    }

    /// How an `AppError` that describes the server's answer was recognised; `nil` for the rest.
    private static func reason(recognising error: AppError) -> String? {
        switch error {
        case .exhentaiAccessDenied, .loginRequired: "recognised before parsing"
        case .ipBanned: "ban page"
        default: nil
        }
    }
}
