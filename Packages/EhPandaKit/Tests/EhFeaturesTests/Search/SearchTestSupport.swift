import EhDatabase
import EhModels
import Foundation
import Synchronization
import Testing

struct ConditionTimeout: Error {}

/// Polls `condition` until it holds, failing after `seconds`. Database observations deliver
/// on their own schedule, so model tests wait for the state they expect.
func eventually(
    _ seconds: Double = 60,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async throws {
    let deadline = ContinuousClock.now + .seconds(seconds)
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Condition not met within \(seconds) s", sourceLocation: sourceLocation)
            throw ConditionTimeout()
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

/// The search history as stored, newest first.
func storedHistory(_ database: AppDatabase) async throws -> [String] {
    var iterator = database.observeSearchHistory().makeAsyncIterator()
    return try await iterator.next() ?? []
}

/// The quick-search words as stored, in order.
func storedWords(_ database: AppDatabase) async throws -> [QuickSearchWord] {
    var iterator = database.observeQuickSearchWords().makeAsyncIterator()
    return try await iterator.next() ?? []
}

func makeGallery(gid: String, title: String = "Title") -> Gallery {
    Gallery(
        gid: gid, token: "token\(gid)", title: title, rating: 4, tags: [], category: .doujinshi,
        uploader: "uploader", pageCount: 10, postedDate: Date(timeIntervalSince1970: 0),
        coverURL: nil, galleryURL: nil
    )
}

// swift-clocks' `TestClock` and `ImmediateClock` yield through background-priority tasks,
// which can stall for minutes on a busy machine; these two never wait on the scheduler.

/// A clock whose sleeps return at once (unless the task is cancelled).
nonisolated struct NoWaitClock: Clock {
    var now: ContinuousClock.Instant { .now }
    var minimumResolution: Duration { .zero }

    func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
    }
}

/// A clock that only moves when the test calls `advance(by:)`.
nonisolated final class ManualClock: Clock, Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var sleepers: [UUID: Sleeper] = [:]
        var cancelled: Set<UUID> = []
    }

    private let state = Mutex(State())

    var now: Instant { state.withLock { $0.now } }
    var minimumResolution: Duration { .zero }
    var sleeperCount: Int { state.withLock { $0.sleepers.count } }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                enum Outcome { case wait, resume, cancel }
                let outcome = state.withLock { state -> Outcome in
                    if state.cancelled.remove(id) != nil { return .cancel }
                    if deadline <= state.now { return .resume }
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return .wait
                }
                switch outcome {
                case .wait: break
                case .resume: continuation.resume()
                case .cancel: continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            let sleeper = state.withLock { state -> Sleeper? in
                guard let sleeper = state.sleepers.removeValue(forKey: id) else {
                    // Cancelled before the sleep registered; it checks this set when it does.
                    state.cancelled.insert(id)
                    return nil
                }
                return sleeper
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(by duration: Duration) {
        let due = state.withLock { state -> [Sleeper] in
            state.now = state.now.advanced(by: duration)
            let due = state.sleepers.filter { $0.value.deadline <= state.now }
            for id in due.keys { state.sleepers[id] = nil }
            return Array(due.values)
        }
        for sleeper in due { sleeper.continuation.resume() }
    }
}
