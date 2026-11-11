import Foundation

/// The parts of the one-time legacy import, in the order they run.
public enum LegacyImportStage: String, Sendable, CaseIterable, Comparable {
    /// Reading `Model.sqlite`.
    case readStore
    /// History, reading progress, search keywords and quick-search words into `AppDatabase`.
    case database
    /// Settings, filters and the user into their stores.
    case preferences
    /// The tag translation dictionary.
    case tagTranslations
    /// Deleting the old store once everything above succeeded.
    case deleteOldStore

    /// The stages whose completion is remembered, so a later launch does not repeat them.
    static let recorded: [LegacyImportStage] = [.database, .preferences, .tagTranslations]

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .readStore: 0
        case .database: 1
        case .preferences: 2
        case .tagTranslations: 3
        case .deleteOldStore: 4
        }
    }
}

/// What a run of `LegacyMigrator` did, for the log.
public struct LegacyImportReport: Sendable, Equatable, CustomStringConvertible {
    public enum Outcome: Sendable, Equatable {
        /// No old store: a fresh install, or the import already finished.
        case nothingToImport
        /// Every stage succeeded and the old store is gone.
        case completed
        /// Something failed; the old store is kept and the failed stages run again next launch.
        case incomplete
    }

    public var outcome: Outcome
    /// Stages that ran and succeeded in this run.
    public var completed: Set<LegacyImportStage> = []
    /// Stages skipped because an earlier launch already completed them.
    public var skipped: Set<LegacyImportStage> = []
    /// Stages that failed in this run, with the error.
    public var failures: [LegacyImportStage: String] = [:]
    /// Galleries in the old history.
    public var historyCount = 0
    /// Which preference parts were imported, and which were unreadable. Unreadable blobs cannot
    /// become readable by retrying, so they are reported but do not fail the import.
    public var preferences: LegacyPreferenceImportReport?

    public init(outcome: Outcome) {
        self.outcome = outcome
    }

    public static let nothingToImport = LegacyImportReport(outcome: .nothingToImport)

    public var description: String {
        var parts = ["Legacy import \(outcome)"]
        if !completed.isEmpty {
            parts.append("completed: \(completed.sorted().map(\.rawValue).joined(separator: ", "))")
        }
        if !skipped.isEmpty {
            parts.append("already done: \(skipped.sorted().map(\.rawValue).joined(separator: ", "))")
        }
        if historyCount > 0 {
            parts.append("\(historyCount) history galleries")
        }
        if let preferences, !preferences.failed.isEmpty {
            parts.append("unreadable preference parts: \(preferences.failed.rawValue)")
        }
        for (stage, error) in failures.sorted(by: { $0.key < $1.key }) {
            parts.append("\(stage.rawValue) failed: \(error)")
        }
        return parts.joined(separator: "; ")
    }
}
