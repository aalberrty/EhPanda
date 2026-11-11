import EhModels
import Foundation
import Synchronization

/// The in-flight work of one model, keyed so that starting a key again replaces its old task.
///
/// Operations started from taps (favourite, rate, vote, a link in a comment) must survive the
/// screen being covered by a pushed child, so they cannot live in a view's `.task`. They live
/// here instead and are cancelled when the model is released, that is when its screen is gone.
/// For that to happen a task must not keep its model alive while it waits: capture what the
/// request needs, await it, and only then reach the model through a weak reference.
nonisolated final class ModelTasks: Sendable {
    private let tasks = Mutex<[String: Task<Void, Never>]>([:])

    init() {}

    deinit {
        tasks.withLock { tasks in
            for task in tasks.values {
                task.cancel()
            }
        }
    }

    /// Starts `operation` on the main actor, cancelling a task still running under `key`.
    @discardableResult
    func run(_ key: String, _ operation: @escaping @MainActor @Sendable () async -> Void) -> Task<Void, Never> {
        let task = Task { @MainActor in await operation() }
        tasks.withLock { tasks in
            tasks[key]?.cancel()
            tasks[key] = task
        }
        return task
    }

    func cancel(_ key: String) {
        tasks.withLock { tasks in
            tasks.removeValue(forKey: key)?.cancel()
        }
    }
}

/// How an awaited request ended, with the client's error contract folded in: `AppError` is a
/// failure to report, cancellation is not.
nonisolated enum Outcome<Value: Sendable>: Sendable {
    case success(Value)
    case failure(AppError)
    case cancelled

    /// Runs `body` on the caller's actor; the client's own work still leaves that actor.
    static func of(
        isolation: isolated (any Actor)? = #isolation, _ body: () async throws -> Value
    ) async -> Outcome<Value> {
        do {
            return .success(try await body())
        } catch is CancellationError {
            return .cancelled
        } catch let error as AppError {
            return Task.isCancelled ? .cancelled : .failure(error)
        } catch {
            return Task.isCancelled ? .cancelled : .failure(.unknown)
        }
    }
}

/// A one-shot result the view turns into a haptic. Each event has its own `id`, so two
/// successes in a row still trigger twice.
public struct OperationFeedback: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case success
        case failure
    }

    public let id: Int
    public let kind: Kind

    public var isSuccess: Bool { kind == .success }
}

/// Hands out `OperationFeedback` values with increasing ids.
struct FeedbackCounter {
    private var count = 0

    mutating func next(_ kind: OperationFeedback.Kind) -> OperationFeedback {
        count += 1
        return OperationFeedback(id: count, kind: kind)
    }
}
