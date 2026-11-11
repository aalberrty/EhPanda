import Foundation

/// Remembers which stages of the legacy import have completed, in `UserDefaults`.
///
/// Every stage is idempotent, but re-running a finished one is not harmless: re-importing the
/// old settings would undo changes the user made since. So a stage runs until it succeeds once,
/// and only the stages that failed run again on a later launch.
struct LegacyImportLedger: Sendable {
    static let key = "legacyImport.completedStages"

    private let storage: PreferenceStorage

    init(storage: PreferenceStorage) {
        self.storage = storage
    }

    init(defaults: UserDefaults) {
        self.init(storage: PreferenceStorage(defaults))
    }

    var completed: Set<LegacyImportStage> {
        let names = storage.defaults.stringArray(forKey: Self.key) ?? []
        return Set(names.compactMap(LegacyImportStage.init(rawValue:)))
    }

    var isEmpty: Bool {
        !storage.contains(Self.key)
    }

    func markCompleted(_ stage: LegacyImportStage) {
        write(completed.union([stage]))
    }

    /// Forgets one stage, e.g. `.database` after the database was dropped and rebuilt empty.
    func forget(_ stage: LegacyImportStage) {
        guard !isEmpty else { return }
        write(completed.subtracting([stage]))
    }

    func reset() {
        storage.defaults.removeObject(forKey: Self.key)
    }

    private func write(_ stages: Set<LegacyImportStage>) {
        storage.defaults.set(stages.sorted().map(\.rawValue), forKey: Self.key)
    }
}
