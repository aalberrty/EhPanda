@testable import EhCore

extension SettingsStore {
    /// A store over private, in-memory defaults.
    static func ephemeral() -> SettingsStore {
        SettingsStore(storage: .ephemeral())
    }
}

import Synchronization

/// A value shared with `@Sendable` dependency closures; a class so closures can capture it.
nonisolated final class SettingsTestLock<Value: Sendable>: Sendable {
    private let mutex: Mutex<Value>

    init(_ value: Value) {
        mutex = Mutex(value)
    }

    var value: Value {
        mutex.withLock { $0 }
    }

    func set(_ newValue: Value) {
        mutex.withLock { $0 = newValue }
    }

    func withLock<Result: Sendable>(_ body: (inout Value) -> Result) -> Result {
        mutex.withLock { body(&$0) }
    }
}
