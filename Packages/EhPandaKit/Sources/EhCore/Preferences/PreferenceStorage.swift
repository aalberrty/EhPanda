import Foundation

/// The `UserDefaults` a preference store reads and writes.
///
/// `@unchecked Sendable` because `UserDefaults` is documented as thread-safe but is not
/// annotated `Sendable` in the SDK; this wrapper holds nothing else. It lets the stores'
/// nonisolated initializers and `GalleryHostProvider` share one defaults across isolation
/// domains.
struct PreferenceStorage: @unchecked Sendable {
    let defaults: UserDefaults

    init(_ defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Private, empty, in-memory defaults for tests and previews: nothing is read from or
    /// written to real preferences or to disk.
    static func ephemeral() -> PreferenceStorage {
        PreferenceStorage(InMemoryDefaults())
    }

    func contains(_ key: String) -> Bool {
        defaults.object(forKey: key) != nil
    }
}

/// `UserDefaults` backed by a dictionary. The typed accessors (`set(_:Bool, forKey:)`,
/// `data(forKey:)`, ...) all funnel into the three primitives overridden here, so the
/// stores' reads and writes never reach the real domain. Other APIs (`register(defaults:)`,
/// `dictionaryRepresentation()`) are not overridden and must not be used with it.
///
/// `@unchecked Sendable` because the dictionary is only touched under `lock`, which keeps it
/// as thread-safe as the `UserDefaults` it stands in for.
private final class InMemoryDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    override func object(forKey key: String) -> Any? {
        lock.withLock { values[key] }
    }

    override func set(_ value: Any?, forKey key: String) {
        lock.withLock { values[key] = value }
    }

    override func removeObject(forKey key: String) {
        lock.withLock { values[key] = nil }
    }
}

/// Encodes and writes JSON preferences on a serial background queue, so JSON coding never
/// runs on the main actor (performance rule 1) and writes land in the order they were made.
final class JSONPreferenceWriter: Sendable {
    private let storage: PreferenceStorage
    private let queue = DispatchQueue(label: "EhCore.JSONPreferenceWriter", qos: .utility)

    init(storage: PreferenceStorage) {
        self.storage = storage
    }

    func write<Value: Encodable & Sendable>(_ value: Value, forKey key: String) {
        queue.async { [storage] in
            do {
                storage.defaults.set(try JSONEncoder().encode(value), forKey: key)
            } catch {
                // Only plain value types are written here; their encoding cannot fail.
                assertionFailure("Failed to encode preference \(key): \(error)")
            }
        }
    }

    func removeValue(forKey key: String) {
        queue.async { [storage] in
            storage.defaults.removeObject(forKey: key)
        }
    }

    /// Blocks until every write queued so far has reached `UserDefaults`. Tests only.
    func waitUntilIdle() {
        queue.sync {}
    }

    /// Reads a JSON preference written by `write(_:forKey:)`; `nil` when absent or invalid.
    static func read<Value: Decodable>(
        _ type: Value.Type, forKey key: String, from storage: PreferenceStorage
    ) -> Value? {
        guard let data = storage.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
