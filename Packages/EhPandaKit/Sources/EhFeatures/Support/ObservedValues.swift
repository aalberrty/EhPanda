import Observation
import Synchronization

/// Calls `body` with what `read` returns now and again after every change to the observable
/// properties it read, until the calling task is cancelled.
///
/// Uses `Observations` where it exists (iOS 26) and an equivalent `withObservationTracking`
/// loop on iOS 18.
@MainActor
func forEachObservedValue<Value: Sendable>(
    of read: @escaping @MainActor @Sendable () -> Value,
    _ body: (Value) -> Void
) async {
    if #available(iOS 26, macOS 26, *) {
        // A closure literal, not `read` itself: converting the `@MainActor` function value to
        // `Observations`' `@isolated(any)` parameter crashed at runtime (Swift 6.2).
        for await value in Observations({ read() }) {
            body(value)
        }
    } else {
        await forEachTrackedValue(of: read, body)
    }
}

/// The iOS 18 path of `forEachObservedValue`: reads under `withObservationTracking`, then waits
/// for its one-shot change callback before reading again.
@MainActor
func forEachTrackedValue<Value>(of read: () -> Value, _ body: (Value) -> Void) async {
    while !Task.isCancelled {
        let signal = ChangeSignal()
        let value = withObservationTracking(read) { signal.fire() }
        body(value)
        await signal.wait()
    }
}

/// A one-shot signal that can fire before, during or after someone waits for it.
nonisolated private final class ChangeSignal: Sendable {
    private enum State {
        case idle
        case fired
        case waiting(CheckedContinuation<Void, Never>)
    }

    private let state = Mutex(State.idle)

    func fire() {
        let waiter: CheckedContinuation<Void, Never>? = state.withLock { state in
            defer { state = .fired }
            if case .waiting(let continuation) = state { return continuation }
            return nil
        }
        waiter?.resume()
    }

    func wait() async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let hasFired = state.withLock { state in
                    if case .fired = state { return true }
                    state = .waiting(continuation)
                    return false
                }
                if hasFired { continuation.resume() }
            }
        } onCancel: {
            fire()
        }
    }
}
