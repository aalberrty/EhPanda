import Synchronization

extension Task where Success == Void, Failure == Never {
    /// Waits until this task finishes or the calling task is cancelled, whichever comes first.
    ///
    /// Unlike `value`, cancelling the caller ends the wait at once and leaves this task running.
    /// A view's task that waits for a load its model owns must not stay suspended, holding the
    /// model, after the view went away: the model could not be released, so its loads could not
    /// be cancelled with it.
    nonisolated func waitUnlessCancelled() async {
        let waiter = Waiter()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiter.set(continuation)
                Task<Void, Never> {
                    await self.value
                    waiter.resume()
                }
            }
        } onCancel: {
            waiter.resume()
        }
    }
}

/// Resumes a continuation exactly once, whichever of the task's completion and the caller's
/// cancellation comes first, including a cancellation that arrives before the continuation.
nonisolated private final class Waiter: Sendable {
    private struct State {
        var continuation: CheckedContinuation<Void, Never>?
        var isResumed = false
    }

    private let state = Mutex(State())

    func set(_ continuation: CheckedContinuation<Void, Never>) {
        let resumeNow = state.withLock { state in
            if state.isResumed { return true }
            state.continuation = continuation
            return false
        }
        if resumeNow { continuation.resume() }
    }

    func resume() {
        let continuation = state.withLock { state -> CheckedContinuation<Void, Never>? in
            state.isResumed = true
            defer { state.continuation = nil }
            return state.continuation
        }
        continuation?.resume()
    }
}
