import Synchronization

/// A few values that are expensive to make, kept by key. The first caller for a key makes the
/// value and everyone after it gets that one; when more than `capacity` keys are held, the
/// one used longest ago goes.
///
/// Made for the tiles of a preview sprite sheet. The image loader hands each of a sheet's
/// twenty tiles the sheet's bytes, and each tile would otherwise decode the whole sheet to
/// cut its own piece out of it.
public nonisolated final class RecentValueCache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private struct State {
        var values: [Key: Value] = [:]
        /// Keys from least to most recently used.
        var order: [Key] = []
    }

    private let capacity: Int
    private let state = Mutex(State())

    public init(capacity: Int) {
        self.capacity = max(capacity, 1)
    }

    /// The value for `key`, made with `make` if it is not held. A `nil` result is not kept.
    ///
    /// `make` runs under the cache's lock: callers that arrive for the same key while it is
    /// being made wait for it instead of making it again. That also makes one caller wait for
    /// another key's value, which is the point for decoding (one at a time) and wrong for
    /// anything that blocks.
    public func value(for key: Key, make: () -> Value?) -> Value? {
        state.withLock { state in
            if let value = state.values[key] {
                state.order.removeAll { $0 == key }
                state.order.append(key)
                return value
            }
            guard let value = make() else { return nil }
            state.values[key] = value
            state.order.append(key)
            if state.order.count > capacity {
                state.values[state.order.removeFirst()] = nil
            }
            return value
        }
    }

    public func removeAll() {
        state.withLock { $0 = State() }
    }
}
