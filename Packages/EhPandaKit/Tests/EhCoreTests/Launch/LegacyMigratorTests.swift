import ConcurrencyExtras
import EhDatabase
@testable import EhCore
import EhModels
import EhTestSupport
import Foundation
import Testing

@MainActor @Suite struct LegacyMigratorTests {
    /// A legacy store, the destination of the import and the ledger, which together survive
    /// "relaunches" (new migrators over the same files and storage).
    @MainActor private final class MigrationFixture {
        let builder: LegacyStoreBuilder
        let directory: URL
        let storage = PreferenceStorage.ephemeral()
        let database: AppDatabase
        let settings: SettingsStore
        let filters: FilterStore
        let user: UserStore
        let importedTagBlobs = LockIsolated<[Data]>([])
        /// Whether the tag translation import fails, per attempt; the last value repeats.
        var tagImportFails: [Bool] = [false]

        init(populate: @MainActor (LegacyStoreBuilder) throws -> Void = LegacyRows.populate) async throws {
            builder = try LegacyStoreBuilder()
            directory = builder.directory
            try populate(builder)
            builder.close()
            database = try await TestDatabase.inMemory()
            settings = SettingsStore(storage: storage)
            filters = FilterStore(storage: storage)
            user = UserStore(storage: storage)
        }

        deinit {
            try? FileManager.default.removeItem(at: directory)
        }

        var ledger: LegacyImportLedger { LegacyImportLedger(storage: storage) }

        var storeExists: Bool {
            FileManager.default.fileExists(atPath: builder.url.path)
        }

        func run(now: Date = LegacyRows.importDate) async -> LegacyImportReport {
            let fails = tagImportFails.count > 1 ? tagImportFails.removeFirst() : tagImportFails[0]
            let blobs = importedTagBlobs
            let migrator = LegacyMigrator(
                store: LegacyStore(url: builder.url), ledger: ledger,
                importTagTranslations: { data in
                    if fails { throw TagImportFailure() }
                    blobs.withValue { $0.append(data) }
                }
            )
            return await migrator.run(database: database, settings: settings, filters: filters, user: user, now: now)
        }
    }

    private struct TagImportFailure: Error {}

    // MARK: Fresh install

    @Test func freshInstallDoesNothing() async throws {
        let directory = try TestDatabase.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = PreferenceStorage.ephemeral()
        let settings = SettingsStore(storage: storage)
        let migrator = LegacyMigrator(
            store: LegacyStore(applicationSupportDirectory: directory), ledger: LegacyImportLedger(storage: storage),
            importTagTranslations: { _ in Issue.record("Nothing to import") }
        )

        let report = await migrator.run(
            database: try await TestDatabase.inMemory(), settings: settings,
            filters: FilterStore(storage: storage), user: UserStore(storage: storage)
        )

        #expect(report == .nothingToImport)
        #expect(storage.storedSettingKeys.isEmpty)
        #expect(LegacyImportLedger(storage: storage).isEmpty)
    }

    // MARK: Full import

    @Test func fullImportMovesEverythingAndDeletesTheOldStore() async throws {
        let fixture = try await MigrationFixture()

        let report = await fixture.run()

        #expect(report.outcome == .completed)
        #expect(report.completed == [.database, .preferences, .tagTranslations, .deleteOldStore])
        #expect(report.failures.isEmpty)
        #expect(report.historyCount == 2)
        #expect(report.preferences?.imported == .all)

        // Database: history, reading progress, keywords, quick-search words.
        let history = try await first(fixture.database.observeHistory())
        #expect(history.map(\.gid) == ["200", "100"])
        #expect(try await fixture.database.state(gid: "100")?.readingProgress == 12)
        #expect(try await first(fixture.database.observeSearchHistory()) == ["newest", "oldest"])
        #expect(try await first(fixture.database.observeQuickSearchWords()).map(\.content) == ["f:glasses$"])
        // Preferences.
        #expect(fixture.settings.galleryHost == .exhentai)
        #expect(fixture.settings.autoLockPolicy == .min1)
        #expect(fixture.user.displayName == "panda")
        #expect(fixture.filters[.search].advanced)
        // Tag translations: the raw blob is handed over.
        #expect(fixture.importedTagBlobs.value == [Data(LegacyRows.tagTranslatorJSON.utf8)])
        // The old store and the progress record are gone.
        #expect(!fixture.storeExists)
        #expect(!FileManager.default.fileExists(atPath: fixture.builder.url.path + "-wal"))
        #expect(fixture.ledger.isEmpty)
    }

    @Test func secondLaunchAfterSuccessDoesNothing() async throws {
        let fixture = try await MigrationFixture()
        _ = await fixture.run()
        fixture.settings.galleryHost = .ehentai

        let report = await fixture.run()

        #expect(report == .nothingToImport)
        #expect(fixture.settings.galleryHost == .ehentai)
        #expect(fixture.importedTagBlobs.value.count == 1)
    }

    @Test func storeWithoutTagTranslatorCompletesWithoutCallingTheService() async throws {
        let fixture = try await MigrationFixture { builder in
            try builder.insert(into: "ZAPPENVMO", ["ZSETTING": LegacyRows.blob(#"{"galleryHost":"ExHentai"}"#)])
        }

        let report = await fixture.run()

        #expect(report.outcome == .completed)
        #expect(fixture.importedTagBlobs.value.isEmpty)
        #expect(fixture.settings.galleryHost == .exhentai)
    }

    @Test func unreadablePreferenceBlobsDoNotBlockCompletion() async throws {
        let fixture = try await MigrationFixture { builder in
            try builder.insert(into: "ZAPPENVMO", [
                "ZSETTING": LegacyRows.blob("not json"), "ZUSER": LegacyRows.blob(#"{"displayName":"panda"}"#)
            ])
        }

        let report = await fixture.run()

        #expect(report.outcome == .completed)
        #expect(report.preferences?.failed == .setting)
        #expect(report.preferences?.imported == .user)
        #expect(!fixture.storeExists)
    }

    // MARK: Failures and retries

    @Test func failedStageKeepsTheOldStoreAndRetriesOnlyThatStage() async throws {
        let fixture = try await MigrationFixture()
        fixture.tagImportFails = [true, false]

        let first = await fixture.run()

        #expect(first.outcome == .incomplete)
        #expect(first.completed == [.database, .preferences])
        #expect(first.failures.keys.sorted() == [.tagTranslations])
        #expect(fixture.storeExists)
        #expect(fixture.ledger.completed == [.database, .preferences])
        #expect(fixture.settings.galleryHost == .exhentai)

        // The user changes a setting before the next launch; the retry must not undo it.
        fixture.settings.galleryHost = .ehentai
        let second = await fixture.run()

        #expect(second.outcome == .completed)
        #expect(second.skipped == [.database, .preferences])
        #expect(second.completed == [.tagTranslations, .deleteOldStore])
        #expect(fixture.settings.galleryHost == .ehentai)
        #expect(fixture.importedTagBlobs.value.count == 1)
        #expect(!fixture.storeExists)
        #expect(fixture.ledger.isEmpty)
    }

    @Test func unreadableStoreIsKeptAndRetried() async throws {
        let fixture = try await MigrationFixture()
        let original = try Data(contentsOf: fixture.builder.url)
        try Data("not a database".utf8).write(to: fixture.builder.url)

        let first = await fixture.run()

        #expect(first.outcome == .incomplete)
        #expect(first.failures.keys.sorted() == [.readStore])
        #expect(first.completed.isEmpty)
        #expect(fixture.storeExists)
        #expect(fixture.ledger.isEmpty)
        #expect(fixture.settings.galleryHost == .ehentai)

        try original.write(to: fixture.builder.url)
        let second = await fixture.run()

        #expect(second.outcome == .completed)
        #expect(fixture.settings.galleryHost == .exhentai)
    }

    @Test func failedDeletionIsRetriedWithoutImportingAgain() async throws {
        let fixture = try await MigrationFixture()
        let store = fixture.builder.url
        try setImmutable(true, store)
        defer { try? setImmutable(false, store) }

        let first = await fixture.run()

        #expect(first.outcome == .incomplete)
        #expect(first.failures.keys.sorted() == [.deleteOldStore])
        #expect(fixture.ledger.completed == [.database, .preferences, .tagTranslations])
        #expect(fixture.storeExists)

        try setImmutable(false, store)
        fixture.settings.galleryHost = .ehentai
        let second = await fixture.run()

        #expect(second.outcome == .completed)
        #expect(second.skipped == [.database, .preferences, .tagTranslations])
        #expect(second.completed == [.deleteOldStore])
        #expect(fixture.settings.galleryHost == .ehentai)
        #expect(fixture.importedTagBlobs.value.count == 1)
        #expect(!fixture.storeExists)
    }

    @Test func rerunningAStageThatWasNotRecordedIsHarmless() async throws {
        // A crash between a stage's work and its record makes it run again next launch.
        let fixture = try await MigrationFixture()
        fixture.tagImportFails = [true]
        _ = await fixture.run()
        fixture.ledger.forget(.database)

        let report = await fixture.run()

        #expect(report.completed == [.database])
        let history = try await first(fixture.database.observeHistory())
        #expect(history.map(\.gid) == ["200", "100"])
        #expect(try await first(fixture.database.observeSearchHistory()) == ["newest", "oldest"])
        #expect(try await first(fixture.database.observeQuickSearchWords()).count == 1)
    }

    @Test func storeRemovedElsewhereClearsStaleProgress() async throws {
        let fixture = try await MigrationFixture()
        fixture.tagImportFails = [true]
        _ = await fixture.run()
        try FileManager.default.removeItem(at: fixture.builder.url)

        let report = await fixture.run()

        #expect(report == .nothingToImport)
        #expect(fixture.ledger.isEmpty)
    }

    // MARK: Ledger

    @Test func ledgerRecordsAndForgetsStages() {
        let ledger = LegacyImportLedger(storage: .ephemeral())
        #expect(ledger.isEmpty)
        ledger.forget(.database)
        #expect(ledger.isEmpty)

        ledger.markCompleted(.preferences)
        ledger.markCompleted(.database)
        #expect(ledger.completed == [.database, .preferences])
        ledger.forget(.database)
        #expect(ledger.completed == [.preferences])
        ledger.reset()
        #expect(ledger.isEmpty)
    }

    @Test func reportDescriptionNamesFailures() {
        var report = LegacyImportReport(outcome: .incomplete)
        report.completed = [.preferences, .database]
        report.failures = [.tagTranslations: "boom"]

        #expect(report.description == "Legacy import incomplete; completed: database, preferences; tagTranslations failed: boom")
    }

    // MARK: Helpers

    /// An immutable file cannot be deleted, while it can still be read.
    private func setImmutable(_ immutable: Bool, _ file: URL) throws {
        try FileManager.default.setAttributes([.immutable: immutable], ofItemAtPath: file.path)
    }
}

/// The first value of a database observation.
func first<S: AsyncSequence & Sendable>(_ sequence: S) async throws -> S.Element where S.Element: Sendable {
    for try await value in sequence {
        return value
    }
    throw CancellationError()
}

/// Rows in the shapes the last legacy release wrote.
enum LegacyRows {
    static let importDate = Date(timeIntervalSince1970: 1_800_000_000)
    static let tagTranslatorJSON = #"{"language":"zh-Hans","translations":{}}"#

    static func blob(_ text: String) -> LegacyStoreBuilder.Value {
        .blob(Data(text.utf8))
    }

    static func populate(_ builder: LegacyStoreBuilder) throws {
        try builder.insert(into: "ZAPPENVMO", [
            "ZUSER": blob(#"{"displayName":"panda"}"#),
            "ZSETTING": blob(#"{"galleryHost":"ExHentai","autoLockPolicy":60,"backgroundBlurRadius":10}"#),
            "ZSEARCHFILTER": blob(#"{"advanced":true}"#),
            "ZGLOBALFILTER": blob(#"{"advanced":true}"#),
            "ZWATCHEDFILTER": blob(#"{"advanced":true}"#),
            "ZTAGTRANSLATOR": blob(tagTranslatorJSON),
            "ZHISTORYKEYWORDS": blob(#"["oldest", "newest"]"#),
            "ZQUICKSEARCHWORDS": blob(#"[{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","name":"Mine","content":"f:glasses$"}]"#)
        ])
        for (gid, opened) in [("100", 700_000_100), ("200", 700_000_300)] {
            try builder.insert(into: "ZGALLERYMO", [
                "ZGID": .text(gid), "ZTOKEN": .text("tok\(gid)"), "ZTITLE": .text("Title \(gid)"),
                "ZCATEGORY": .text("Manga"), "ZPAGECOUNT": .int(30), "ZPOSTEDDATE": .int(700_000_000),
                "ZGALLERYURL": .text("https://e-hentai.org/g/\(gid)/tok\(gid)/"), "ZLASTOPENDATE": .int(opened)
            ])
        }
        try builder.insert(into: "ZGALLERYSTATEMO", ["ZGID": .text("100"), "ZREADINGPROGRESS": .int(12)])
    }
}
