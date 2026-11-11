/// Lets a fixed number of jobs run at once.
///
/// Waiters are served newest first: when a reader flings through many pages, the pages it
/// lands on are the ones worth decoding. A waiter whose task is cancelled leaves the queue at
/// once instead of holding its place (and its data) until a slot frees up.
actor ConcurrencyLimiter {
    private let limit: Int
    private var running = 0
    private var nextID = 0
    private var waiters: [(id: Int, continuation: CheckedContinuation<Void, any Error>)] = []

    init(limit: Int) {
        self.limit = max(limit, 1)
    }

    /// Waits for a slot. Throws `CancellationError` if the task is cancelled while waiting.
    /// Every successful call must be balanced by `release()`.
    func acquire() async throws {
        try Task.checkCancellation()
        if running < limit {
            running += 1
            return
        }
        let id = nextID
        nextID += 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append((id, continuation))
                }
            }
        } onCancel: {
            Task { await self.abandon(id) }
        }
    }

    func release() {
        if let next = waiters.popLast() {
            // The slot goes straight to the waiter, so `running` stays as it is.
            next.continuation.resume()
        } else {
            running -= 1
        }
    }

    private func abandon(_ id: Int) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
