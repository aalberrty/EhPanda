import Foundation

/// Retries transient failures of another transport according to a `RetryPolicy`.
public struct RetryingTransport: HTTPTransport {
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    private let base: any HTTPTransport
    private let policy: RetryPolicy
    private let sleep: Sleep
    private let random: @Sendable () -> Double

    /// - Parameters:
    ///   - sleep: Waits between attempts. Tests inject a recorder so they run instantly.
    ///   - random: Source of jitter in `0..<1`.
    public init(
        _ base: any HTTPTransport,
        policy: RetryPolicy = .default,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
        random: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.base = base
        self.policy = policy
        self.sleep = sleep
        self.random = random
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        var attempt = 1
        while true {
            do {
                return try await base.send(request)
            } catch {
                let urlError = URLError.normalized(error)
                guard attempt < policy.maxAttempts,
                      urlError.code != .cancelled,
                      !Task.isCancelled,
                      policy.shouldRetry(method: request.httpMethod, error: urlError)
                else { throw urlError }

                do {
                    try await sleep(policy.delay(afterAttempt: attempt, random: random()))
                } catch {
                    throw URLError.normalized(error)
                }
                if Task.isCancelled { throw URLError(.cancelled) }
                attempt += 1
            }
        }
    }
}
