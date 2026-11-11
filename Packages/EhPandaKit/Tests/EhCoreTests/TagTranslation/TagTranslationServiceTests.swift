import EhDatabase
import EhModels
import Foundation
import Testing
@testable import EhCore

@MainActor
@Suite struct TagTranslationServiceTests {
    // MARK: Update flow

    @Test func firstDownloadStoresTranslationsAndMetadata() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)

        await harness.service.fetchUpdates()

        let service = harness.service
        #expect(service.loadingState == .idle)
        #expect(service.metadata == TagTranslationMetadata(
            language: .simplifiedChinese, updatedDate: Samples.releaseDate
        ))
        #expect(service.display(forKey: "femalebig breasts")?.displayValue == "巨乳")
        #expect(service.display(forKey: "parodytouhou project") == TagTranslationDisplay(
            displayValue: "东方Project", valueImageURL: URL(string: "https://ehgt.org/touhou.webp")
        ))
        #expect(try await harness.database.tagTranslationCount() == 3)
        // Persisted: a new service on the same defaults and database sees the same state.
        let reopened = TagTranslationService(
            database: AppDatabaseProvider(harness.database), remote: harness.remote.remote, defaults: harness.defaults
        )
        await reopened.load()
        #expect(reopened.metadata == service.metadata)
        #expect(reopened.translations == service.translations)
        let checks = harness.remote.state.withLock { $0.releaseChecks }
        #expect(checks.count == 1)
        #expect(checks.first?.0 == .simplifiedChinese)
        #expect(checks.first?.1 == .distantPast)
    }

    @Test func noUpdatesKeepsStoredTranslations() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()

        await harness.service.fetchUpdates()

        #expect(harness.service.loadingState == .failed(.noUpdates))
        #expect(harness.remote.downloadCount == 1)
        #expect(harness.service.translations.count == 3)
        #expect(harness.remote.state.withLock { $0.releaseChecks.last?.1 } == Samples.releaseDate)
    }

    @Test func newerReleaseReplacesTranslations() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()
        let later = Samples.releaseDate.addingTimeInterval(86_400)
        harness.remote.publish(
            .simplifiedChinese, date: later, translations: Samples.keyed([Samples.translation(.male, "yaoi", "耽美")])
        )

        await harness.service.fetchUpdates()

        #expect(harness.service.translations.keys.sorted() == ["maleyaoi"])
        #expect(harness.service.updatedDate == later)
        #expect(try await harness.database.tagTranslationCount() == 1)
    }

    @Test func languageChangeResetsAndDownloadsTheNewLanguage() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()
        harness.languages.set(["ja-JP"])
        harness.remote.publish(
            .japanese, date: Samples.releaseDate.addingTimeInterval(-1),
            translations: Samples.keyed([Samples.translation(.female, "big breasts", "巨乳（日）")])
        )

        await harness.service.fetchUpdates()

        #expect(harness.service.language == .japanese)
        #expect(harness.service.translations.keys.sorted() == ["femalebig breasts"])
        #expect(harness.service.display(forKey: "femalebig breasts")?.displayValue == "巨乳（日）")
        // The date check started over from the distant past for the new language.
        #expect(harness.remote.state.withLock { $0.releaseChecks.last?.1 } == .distantPast)
    }

    @Test func languageChangeClearsEvenIfTheDownloadFails() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()
        harness.languages.set(["en-US"])

        await harness.service.fetchUpdates()

        #expect(harness.service.loadingState == .failed(.networkingFailed))
        #expect(harness.service.metadata == TagTranslationMetadata(language: .english))
        #expect(harness.service.isEmpty)
        #expect(try await harness.database.tagTranslationCount() == 0)
    }

    @Test func untranslatableLanguageDoesNothing() async throws {
        let harness = try await ServiceHarness.make(languages: ["fr-FR", "zh-Hans"])
        await harness.service.fetchUpdates()
        #expect(harness.service.loadingState == .idle)
        #expect(harness.remote.state.withLock { $0.releaseChecks.isEmpty })
    }

    @Test func failedDownloadLeavesExistingDataIntact() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate.addingTimeInterval(60), translations: [:])
        harness.remote.state.withLock { $0.downloadError = URLError(.timedOut) }

        await harness.service.fetchUpdates()

        #expect(harness.service.loadingState == .failed(.networkingFailed))
        #expect(harness.service.updatedDate == Samples.releaseDate)
        #expect(harness.service.translations.count == 3)
        #expect(try await harness.database.tagTranslationCount() == 3)
    }

    @Test func emptyDownloadIsAParseFailure() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: [:])
        await harness.service.fetchUpdates()
        #expect(harness.service.loadingState == .failed(.parseFailed))
        #expect(harness.service.updatedDate == .distantPast)
    }

    @Test func concurrentCallsShareOneDownload() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        let gate = harness.remote.holdReleaseCheck()
        let service = harness.service

        async let first: Void = service.fetchUpdates()
        async let second: Void = service.fetchUpdates()
        async let third: Void = service.fetchUpdates()
        while harness.remote.state.withLock({ $0.releaseChecks.isEmpty }) { await Task.yield() }
        #expect(service.loadingState == .loading)
        gate.finish()
        _ = await (first, second, third)

        #expect(harness.remote.state.withLock { $0.releaseChecks.count } == 1)
        #expect(harness.remote.downloadCount == 1)
        #expect(service.translations.count == 3)
    }

    @Test func traditionalChineseDownloadIsConverted() async throws {
        let harness = try await ServiceHarness.make(languages: ["zh-Hant-TW"])
        harness.remote.publish(
            .traditionalChinese, date: Samples.releaseDate,
            translations: Samples.keyed([Samples.translation(.other, "full color", "full color"),
                                         Samples.translation(.female, "big breasts", "巨乳头发")])
        )
        await harness.service.fetchUpdates()
        #expect(harness.service.display(forKey: "otherfull color")?.displayValue == "全彩")
        #expect(harness.service.display(forKey: "femalebig breasts")?.displayValue == "巨乳頭髮")
    }

    // MARK: Custom translations

    @Test func customImportReplacesAndBlocksDownloads() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()

        await harness.service.importCustomTranslations(from: Samples.databaseFile([
            "female": ["big breasts": "自定义巨乳", "glasses": "![图](https://ehgt.org/g.jpg)眼镜"],
            "unknownnamespace": ["x": "y"]
        ]))

        let service = harness.service
        #expect(service.loadingState == .idle)
        #expect(service.metadata == TagTranslationMetadata(hasCustomTranslations: true))
        #expect(service.translations.keys.sorted() == ["femalebig breasts", "femaleglasses"])
        #expect(service.display(forKey: "femaleglasses")?.valueImageURL == URL(string: "https://ehgt.org/g.jpg"))

        harness.remote.publish(
            .simplifiedChinese, date: Samples.releaseDate.addingTimeInterval(60), translations: Samples.chinese
        )
        await service.fetchUpdates()
        #expect(harness.remote.downloadCount == 1)
        #expect(service.display(forKey: "femalebig breasts")?.displayValue == "自定义巨乳")
    }

    @Test func invalidCustomFileFailsWithoutChanges() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()

        await harness.service.importCustomTranslations(from: Data("not json".utf8))
        #expect(harness.service.loadingState == .failed(.parseFailed))
        await harness.service.importCustomTranslations(from: Samples.databaseFile(["unknown": ["x": "y"]]))
        #expect(harness.service.loadingState == .failed(.parseFailed))

        #expect(!harness.service.hasCustomTranslations)
        #expect(harness.service.translations.count == 3)
    }

    @Test func removingCustomTranslationsClearsThemAndAllowsDownloads() async throws {
        let harness = try await ServiceHarness.make()
        await harness.service.importCustomTranslations(from: Samples.databaseFile(["female": ["a": "甲"]]))

        await harness.service.removeCustomTranslations()

        #expect(harness.service.isEmpty)
        #expect(!harness.service.hasCustomTranslations)
        #expect(try await harness.database.tagTranslationCount() == 0)
        #expect(TagTranslationMetadata(defaults: harness.defaults) == TagTranslationMetadata())

        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()
        #expect(harness.service.translations.count == 3)
    }

    @Test func removeWithoutCustomTranslationsKeepsDownloads() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()
        await harness.service.removeCustomTranslations()
        #expect(harness.service.translations.count == 3)
    }

    // MARK: Lookup and details

    @Test func lookupMatchesLegacy() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()
        let service = harness.service

        #expect(service.lookup(word: "femalebig breasts", returnOriginal: false).text == "巨乳")
        #expect(service.lookup(word: "female:big breasts", returnOriginal: false).text == "female:巨乳")
        #expect(service.lookup(word: "female:big breasts", returnOriginal: false).key == "femalebig breasts")
        #expect(service.lookup(word: "female:big breasts", returnOriginal: true).text == "female:big breasts")
        #expect(service.lookup(word: "female:unknown", returnOriginal: false).display == nil)
        #expect(service.lookup(word: "female:unknown", returnOriginal: false).text == "female:unknown")
        #expect(TagTranslationService.splitAtColon(":big") == (nil, ":big"))
        #expect(TagTranslationService.splitAtColon("a::b") == ("a", "b"))
    }

    @Test func detailsAreComputedOnDemand() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()

        let details = await harness.service.details(forKeys: ["femalebig breasts", "femalelolicon", "femalenone"])

        #expect(details == ["femalebig breasts": TagDetail(
            title: "巨乳", description: "乳房较大。", imageURLs: [URL(string: "https://ehgt.org/a.jpg")!], links: []
        )])
    }

    @Test func loadPublishesStoredTable() async throws {
        let harness = try await ServiceHarness.make()
        let prepared = await TagTranslationService.prepare(Samples.chinese, traditionalChineseFor: nil)
        try await harness.database.replaceTagTranslations(prepared.rows)
        #expect(!harness.service.isLoaded)

        await harness.service.load()

        #expect(harness.service.isLoaded)
        #expect(harness.service.translations == prepared.table)
    }
}
