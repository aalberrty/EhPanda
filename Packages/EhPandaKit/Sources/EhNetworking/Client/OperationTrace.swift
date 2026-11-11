import EhModels
import Foundation
import Synchronization

/// The last request and response of one client operation, kept so that a failure can be
/// explained by what the server actually sent.
///
/// `EhClient.perform` binds a trace to its task for the duration of the operation and
/// `send` records into it, which keeps every operation's body unchanged: the trace travels
/// with the task instead of through each helper's parameters. Operations that send several
/// requests are explained by the last one, which is the one whose body failed.
final class OperationTrace: Sendable {
    @TaskLocal static var current: OperationTrace?

    private struct State {
        var request: URLRequest?
        var response: (request: URLRequest, response: HTTPResponse)?
    }

    private let state = Mutex(State())

    func willSend(_ request: URLRequest) {
        state.withLock { $0.request = request }
    }

    func didReceive(_ response: HTTPResponse, for request: URLRequest) {
        state.withLock { $0.response = (request, response) }
    }

    /// The last request sent, whether or not it was answered.
    var lastRequest: RequestSummary? {
        state.withLock { $0.request }.map(RequestSummary.init)
    }

    /// The last answered request. Built on demand, so a successful operation pays nothing
    /// beyond keeping a reference to its last body.
    var lastResponse: ResponseSnapshot? {
        state.withLock { $0.response }.map { ResponseSnapshot(request: $0.request, response: $0.response) }
    }
}

/// One failed operation whose failure came from what the server sent (a parse error or a
/// recognised non-content answer), described for the log.
public struct EhClientFailure: Sendable, CustomStringConvertible {
    /// The `EhClient` method, e.g. `favoriteCategories()`.
    public let operation: String
    public let error: AppError
    /// How the error was decided, e.g. "recognised before parsing" or "classified from parseFailed".
    let reason: String
    let request: RequestSummary?
    let response: ResponseSnapshot?

    /// One line: operation, error, how it was decided, and the request and response without
    /// cookies, headers or query values.
    public var description: String {
        var text = "\(operation) failed: \(error) (\(reason))"
        if let response {
            text += "; " + response.logDescription
        } else if let request {
            text += "; " + request.logDescription
        }
        return text
    }
}
