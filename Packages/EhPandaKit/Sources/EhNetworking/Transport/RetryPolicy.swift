import Foundation

/// When and how long `RetryingTransport` waits before trying a request again.
///
/// Rules:
/// - Only thrown `URLError`s are retried. Responses, whatever their status, never are.
/// - `GET` and `HEAD` are idempotent, so they are retried on any error in `transientErrors`.
/// - Every other method may change server state, so it is retried only on errors in
///   `undeliveredErrors`, which guarantee the request never reached the server. A `POST` that
///   may have been delivered is never replayed.
/// - `URLError.cancelled` and cancellation of the calling task are never retried.
/// - At most `maxTimeoutAttempts` attempts may time out. Each costs a full request timeout, so a
///   server that does not answer would otherwise keep a spinner up for `maxAttempts` timeouts.
/// - Before attempt *n* + 1 the transport waits `baseDelay * 2^(n-1)`, plus a random jitter of
///   up to `jitterFraction` of that delay so that clients that failed together do not retry in step.
public struct RetryPolicy: Sendable {
    /// Total attempts, including the first.
    public var maxAttempts: Int
    public var baseDelay: Duration
    public var jitterFraction: Double
    /// Attempts that may end in `URLError.timedOut`, counting the first.
    public var maxTimeoutAttempts: Int

    public init(
        maxAttempts: Int = 3, baseDelay: Duration = .milliseconds(500), jitterFraction: Double = 0.25,
        maxTimeoutAttempts: Int = 2
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.jitterFraction = jitterFraction
        self.maxTimeoutAttempts = maxTimeoutAttempts
    }

    public static let `default` = RetryPolicy()

    /// Failures where the request did not leave the device or no connection was established,
    /// so the server cannot have processed it. `secureConnectionFailed` is raised during the TLS
    /// handshake, before any request bytes are sent.
    public static let undeliveredErrors: Set<URLError.Code> = [
        .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
        .notConnectedToInternet, .secureConnectionFailed
    ]

    /// Failures worth retrying for idempotent requests.
    public static let transientErrors: Set<URLError.Code> = undeliveredErrors.union([
        .timedOut, .networkConnectionLost, .badServerResponse, .unknown
    ])

    /// Whether a request with `method` that failed with `error` should be attempted again.
    public func shouldRetry(method: String?, error: URLError) -> Bool {
        switch (method ?? "GET").uppercased() {
        case "GET", "HEAD": Self.transientErrors.contains(error.code)
        default: Self.undeliveredErrors.contains(error.code)
        }
    }

    /// Whether to try again after failed attempt number `attempt` (1-based), when `timeouts` of
    /// the attempts so far, this one included, timed out.
    public func shouldRetry(method: String?, error: URLError, attempt: Int, timeouts: Int) -> Bool {
        guard attempt < maxAttempts, error.code != .cancelled else { return false }
        if error.code == .timedOut, timeouts >= maxTimeoutAttempts { return false }
        return shouldRetry(method: method, error: error)
    }

    /// The wait before the attempt that follows failed attempt number `attempt` (1-based).
    /// - Parameter random: A value in `0..<1` that scales the jitter.
    public func delay(afterAttempt attempt: Int, random: Double) -> Duration {
        let exponential = baseDelay * (1 << max(0, attempt - 1))
        return exponential + exponential * (jitterFraction * random)
    }
}
