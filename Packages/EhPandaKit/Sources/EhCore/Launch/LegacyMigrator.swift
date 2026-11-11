import EhDatabase
import EhModels
import Foundation

/// Moves the data of EhPanda 2.x into this app, once.
///
/// Runs at launch, before the first screen. The stages are independent and idempotent:
/// - **database**: history, reading progress, search keywords and quick-search words;
/// - **preferences**: settings, the three filters and the user;
/// - **tag translations**: the downloaded or imported dictionary.
///
/// A stage that succeeds is recorded and never runs again, so later launches cannot undo
/// changes the user made in the meantime. A stage that fails is logged by the caller and retried
/// next launch; it never blocks the launch. The old store holds the user's browsing history, so
/// it is deleted as soon as, and only once, every stage has succeeded. A fresh install (no old
/// store) costs one file-existence check off the main actor.
public struct LegacyMigrator: Sendable {
    /// Imports the legacy `TagTranslator` JSON blob into the tag translation service.
    public typealias TagTranslationImport = @MainActor @Sendable (Data) async throws -> Void

    let store: LegacyStore
    let ledger: LegacyImportLedger
    let importTagTranslations: TagTranslationImport

    public init(store: LegacyStore, defaults: UserDefaults, importTagTranslations: @escaping TagTranslationImport) {
        self.init(store: store, ledger: LegacyImportLedger(defaults: defaults), importTagTranslations: importTagTranslations)
    }

    init(store: LegacyStore, ledger: LegacyImportLedger, importTagTranslations: @escaping TagTranslationImport) {
        self.store = store
        self.ledger = ledger
        self.importTagTranslations = importTagTranslations
    }

    /// Runs whatever is left of the import.
    ///
    /// - Parameter now: imported search keywords are dated just before it.
    @MainActor
    public func run(
        database: AppDatabase, settings: SettingsStore, filters: FilterStore, user: UserStore,
        now: Date = .now
    ) async -> LegacyImportReport {
        guard await store.exists() else {
            // Stale progress from an import whose files were removed some other way.
            if !ledger.isEmpty { ledger.reset() }
            return .nothingToImport
        }
        var report = LegacyImportReport(outcome: .incomplete)
        let pending = LegacyImportStage.recorded.filter { !ledger.completed.contains($0) }
        report.skipped = Set(LegacyImportStage.recorded).subtracting(pending)

        if !pending.isEmpty {
            let snapshot: LegacySnapshot
            do {
                snapshot = try await store.readSnapshot()
            } catch {
                report.failures[.readStore] = Self.describe(error)
                return report
            }
            report.historyCount = snapshot.history.count
            for stage in pending {
                do {
                    try await run(stage, snapshot: snapshot, now: now, into: (database, settings, filters, user), report: &report)
                    ledger.markCompleted(stage)
                    report.completed.insert(stage)
                } catch {
                    report.failures[stage] = Self.describe(error)
                }
            }
        }
        guard report.failures.isEmpty else { return report }

        do {
            try await store.deleteFiles()
            ledger.reset()
            report.completed.insert(.deleteOldStore)
            report.outcome = .completed
        } catch {
            // Every stage is recorded, so the next launch only retries the deletion.
            report.failures[.deleteOldStore] = Self.describe(error)
        }
        return report
    }

    @MainActor
    private func run(
        _ stage: LegacyImportStage, snapshot: LegacySnapshot, now: Date,
        into destination: (database: AppDatabase, settings: SettingsStore, filters: FilterStore, user: UserStore),
        report: inout LegacyImportReport
    ) async throws {
        let environment = snapshot.appEnvironment
        switch stage {
        case .database:
            try await destination.database.importLegacyData(snapshot, at: now)
        case .preferences:
            let blobs = LegacyPreferenceBlobs(
                setting: environment.setting, user: environment.user,
                searchFilter: environment.searchFilter, globalFilter: environment.globalFilter,
                watchedFilter: environment.watchedFilter
            )
            report.preferences = await blobs.apply(
                to: destination.settings, filters: destination.filters, user: destination.user
            )
        case .tagTranslations:
            if let blob = environment.tagTranslator {
                try await importTagTranslations(blob)
            }
        case .readStore, .deleteOldStore:
            break
        }
    }

    private static func describe(_ error: any Error) -> String {
        String(describing: error)
    }
}
