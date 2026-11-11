import Dependencies
import EhDatabase
import EhFeatures
import EhModels
import EhTestSupport
import Foundation
import Testing
@testable import EhCore

@Suite struct TagTranslationSettingsModelTests {
    nonisolated private static let releaseDate = Date(timeIntervalSince1970: 1_700_000_000)
    nonisolated private static let english: [String: TagTranslation] = [
        "femalelolicon": TagTranslation(namespace: .female, key: "lolicon", value: "Lolicon")
    ]

    private struct Harness {
        let model: TagTranslationSettingsModel
        let service: TagTranslationService
        let settings: SettingsStore
        let database: AppDatabase
        let downloads: Locked<Int>
    }

    /// A service over an in-memory database whose remote publishes `translations` (or fails
    /// when `nil`), for a user whose preferred language is `language`.
    private func makeHarness(
        translations: [String: TagTranslation]?, language: String = "en-US"
    ) async throws -> Harness {
        let database = try await TestDatabase.inMemory()
        let downloads = Locked(0)
        let remote = TagTranslationRemote(
            latestReleaseDate: { _, _ in
                guard translations != nil else { throw URLError(.notConnectedToInternet) }
                return Self.releaseDate
            },
            downloadDatabase: { _ in
                downloads.withLock { $0 += 1 }
                return translations ?? [:]
            }
        )
        let service = TagTranslationService(
            database: AppDatabaseProvider(database), remote: remote, defaults: .ephemeral(),
            preferredLanguages: { [language] }
        )
        let settings = SettingsStore.ephemeral()
        let model = withDependencies {
            $0.tagTranslationService = service
            $0.settings = settings
        } operation: { TagTranslationSettingsModel() }
        return Harness(model: model, service: service, settings: settings, database: database, downloads: downloads)
    }

    @Test func enablingTheExtensionDownloadsAndShowsTheOptions() async throws {
        let harness = try await makeHarness(translations: Self.english)
        await harness.model.onAppear()
        #expect(!harness.model.showsTranslationOptions)

        await harness.model.setEnablesTagsExtension(true)

        #expect(harness.settings.enablesTagsExtension)
        #expect(harness.downloads.value == 1)
        #expect(harness.model.showsTranslationOptions)
        #expect(!harness.model.isLoading)
        #expect(harness.model.failure == nil)
        #expect(try await harness.database.tagTranslationLookup()["femalelolicon"]?.displayValue == "Lolicon")
    }

    @Test func disablingTheExtensionTurnsItsOptionsOffWithoutDownloading() async throws {
        let harness = try await makeHarness(translations: Self.english)
        await harness.model.setEnablesTagsExtension(true)
        harness.settings.translatesTags = true
        harness.settings.showsImagesInTags = true

        await harness.model.setEnablesTagsExtension(false)

        #expect(!harness.settings.translatesTags)
        #expect(!harness.settings.showsImagesInTags)
        #expect(!harness.model.showsTranslationOptions)
        #expect(harness.downloads.value == 1)
    }

    @Test func aFailedDownloadIsShownAndTheEmptyWarningAppears() async throws {
        let harness = try await makeHarness(translations: nil)

        await harness.model.setEnablesTagsExtension(true)
        harness.settings.translatesTags = true

        #expect(harness.model.failure == .networkingFailed)
        #expect(harness.model.showsEmptyWarning)
        #expect(!harness.model.showsTranslationOptions)
    }

    @Test func noUpdatesIsNotAFailure() async throws {
        let harness = try await makeHarness(translations: Self.english)
        await harness.model.setEnablesTagsExtension(true)

        await harness.model.setEnablesTagsExtension(true)

        #expect(harness.downloads.value == 1)
        #expect(harness.model.failure == nil)
    }

    @Test func anUntranslatableLanguageDownloadsNothing() async throws {
        let harness = try await makeHarness(translations: Self.english, language: "de-DE")

        await harness.model.setEnablesTagsExtension(true)

        #expect(harness.downloads.value == 0)
        #expect(harness.model.failure == nil)
        #expect(!harness.model.showsTranslationOptions)
    }

    @Test func importingAndRemovingCustomTranslations() async throws {
        let harness = try await makeHarness(translations: Self.english)
        harness.settings.enablesTagsExtension = true
        let file = try writeDatabaseFile(["female": ["big breasts": "Custom"]])
        defer { try? FileManager.default.removeItem(at: file) }

        await harness.model.importCustomTranslations(from: file)

        #expect(harness.model.hasCustomTranslations)
        #expect(harness.model.showsTranslationOptions)
        #expect(try await harness.database.tagTranslationLookup()["femalebig breasts"]?.displayValue == "Custom")
        // Downloads are skipped while custom translations are in use.
        await harness.model.setEnablesTagsExtension(true)
        #expect(harness.downloads.value == 0)

        await harness.model.removeCustomTranslations()

        #expect(!harness.model.hasCustomTranslations)
        #expect(try await harness.database.tagTranslationLookup().isEmpty)
        #expect(!harness.model.showsTranslationOptions)
    }

    @Test func anInvalidOrMissingFileFails() async throws {
        let harness = try await makeHarness(translations: Self.english)
        let directory = try TestDatabase.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let invalid = directory.appending(path: "db.raw.json")
        try Data("not json".utf8).write(to: invalid)

        await harness.model.importCustomTranslations(from: invalid)
        #expect(harness.model.failure == .parseFailed)
        #expect(!harness.model.hasCustomTranslations)

        await harness.model.importCustomTranslations(from: directory.appending(path: "missing.json"))
        #expect(harness.model.failure == .parseFailed)
        #expect(!harness.model.hasCustomTranslations)
    }

    private func writeDatabaseFile(_ entries: [String: [String: String]]) throws -> URL {
        let response = EhTagTranslationDatabaseResponse(data: entries.map { namespace, names in
            .init(namespace: namespace, data: names.mapValues { .init(name: $0, intro: "", links: "") })
        })
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        try JSONEncoder().encode(response).write(to: url)
        return url
    }
}
