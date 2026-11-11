import EhDatabase
import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@MainActor
@Suite struct GalleryDetailLoadingTests {
    @Test func initDoesNoWork() async throws {
        let env = try await DetailEnvironment()
        let model = env.makeDetailModel()
        #expect(model.detail == nil)
        #expect(model.loadingState == .idle)
        #expect(env.transport.requests.isEmpty)
    }

    @Test func showsStoredContentThenTheFreshPage() async throws {
        let env = try await DetailEnvironment()
        let stored = GalleryDetail(
            gid: DetailEnvironment.gid, title: "Stored title", isFavorited: false, visibility: .yes, rating: 3,
            userRating: 2.5, ratingCount: 1, category: .nonH, language: .japanese, uploader: "Stored uploader",
            postedDate: .now, coverURL: nil, favoritedCount: 1, pageCount: 156, sizeCount: 1, sizeType: "MiB",
            torrentCount: 0
        )
        try await env.database.saveDetail(stored)
        try await env.database.updateTags(gid: DetailEnvironment.gid, tags: [
            GalleryTag(rawNamespace: "female", contents: [
                .init(rawNamespace: "female", text: "stored", isVotedUp: false, isVotedDown: false, backgroundColor: nil)
            ])
        ])
        try await env.database.upsertPages([
            GalleryPage(gid: DetailEnvironment.gid, index: 1, previewURL: URL(string: "https://ehgt.org/stored.jpg"))
        ])

        let (gate, release) = AsyncStream<Void>.makeStream()
        env.transport.on(.path(DetailEnvironment.detailPath), reply: .handler { request in
            for await _ in gate { break }
            return try fixtureResponse("Parser/Gallery/GalleryDetail.html", for: request)
        })
        let model = env.makeDetailModel()
        let loading = Task { await model.load() }

        await pollUntil { model.detail?.title == "Stored title" && model.loadingState == .loading }
        #expect(model.userRating == 5)
        #expect(model.tagRows.map(\.tag.rawNamespace) == ["female"])
        #expect(model.previews.map(\.index) == [1])

        release.yield()
        await loading.value

        #expect(model.loadingState == .idle)
        #expect(model.detail?.title == "[Artist] mks")
        #expect(model.tagRows.map(\.tag.rawNamespace) == ["other"])
        #expect(model.previews.count == 40)
        #expect(model.comments.count == 10)
        #expect(model.previewConfig == .normal(rows: 4))
        #expect(model.apiKey == "000000000000000000")
        #expect(env.userStore.apikey == "000000000000000000")
    }

    @Test func recordsTheVisitInTheHistory() async throws {
        let env = try await DetailEnvironment()
        _ = await env.loadedDetailModel()
        let recorded = try await env.database.gallery(gid: DetailEnvironment.gid)
        #expect(recorded?.title == "List title")
        #expect(recorded?.lastOpenDate != nil)
    }

    @Test func storesDetailTagsCommentsAndPreviews() async throws {
        let env = try await DetailEnvironment()
        _ = await env.loadedDetailModel()
        let database = env.database
        let gid = DetailEnvironment.gid

        // Storing happens after the screen has what it needs, so wait for the last write.
        await pollUntil { (try? await database.state(gid: gid))?.previewConfig != nil }
        let pages = try await database.pages(gid: gid)
        #expect(pages.compactMap(\.previewURL).count == 40)
        let detail = try await database.detail(gid: gid)
        #expect(detail?.title == "[Artist] mks")
        let state = try #require(try await database.state(gid: gid))
        #expect(state.tags.map(\.rawNamespace) == ["other"])
        #expect(state.comments.count == 10)
        #expect(state.previewConfig == .normal(rows: 4))
    }

    @Test func failureThenRetry() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.path(DetailEnvironment.detailPath), reply: .error(URLError(.timedOut)))
        let model = env.makeDetailModel()
        await model.load()
        #expect(model.loadingState == .failed(.networkingFailed))
        #expect(model.loadingState.failed?.isRetryable == true)

        env.serveDetail()
        model.refetch()
        await pollUntil { model.detail != nil && model.loadingState == .idle }
        #expect(model.detail?.title == "[Artist] mks")
    }

    @Test func expungedGalleryIsNotRetryable() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(
            .path(DetailEnvironment.detailPath),
            reply: .html(#"<div class="d"><p>This gallery has been removed or is unavailable.</p></div>"#)
        )
        let model = env.makeDetailModel()
        await model.load()
        #expect(model.loadingState == .failed(.expunged("This gallery has been removed or is unavailable.")))
        #expect(model.loadingState.failed?.isRetryable == false)
    }

    @Test func galleryWithoutURLFailsWithoutRequest() async throws {
        let env = try await DetailEnvironment()
        let gallery = Gallery(
            gid: "1", token: "t", title: "", rating: 0, tags: [], category: .misc, pageCount: 1,
            postedDate: .now, coverURL: nil, galleryURL: nil
        )
        let model = env.makeDetailModel(gallery: gallery)
        await model.load()
        #expect(model.loadingState == .failed(.notFound))
        #expect(env.detailFetchCount == 0)
    }

    @Test func loadingTwiceFetchesOnce() async throws {
        let env = try await DetailEnvironment()
        let model = await env.loadedDetailModel()
        await model.load()
        #expect(env.detailFetchCount == 1)
    }

    @Test func titlePrefersJapaneseWhenAsked() async throws {
        let env = try await DetailEnvironment()
        let model = env.makeDetailModel()
        #expect(model.title(prefersJapanese: true) == "List title")
        env.serveDetail()
        await model.load()
        #expect(model.title(prefersJapanese: true) == "[アーティスト] mks")
        #expect(model.title(prefersJapanese: false) == "[Artist] mks")
    }
}

@MainActor
@Suite struct GalleryDetailGreetingTests {
    @Test func greetingIsStoredAndAnnouncedWhenEnabled() async throws {
        let env = try await DetailEnvironment()
        env.settings.showsNewDawnGreeting = true
        let model = await env.loadedDetailModel(fixture: "Parser/Other/GalleryDetailWithGreeting.html")
        #expect(env.userStore.greeting?.gainedEXP == 30)
        #expect(model.greetingToAnnounce?.gainedCredits == 329)
        model.greetingAnnounced()
        #expect(model.greetingToAnnounce == nil)
    }

    @Test func greetingIsStoredButNotAnnouncedWhenDisabled() async throws {
        let env = try await DetailEnvironment()
        env.settings.showsNewDawnGreeting = false
        let model = await env.loadedDetailModel(fixture: "Parser/Other/GalleryDetailWithGreeting.html")
        #expect(env.userStore.greeting?.gainedEXP == 30)
        #expect(model.greetingToAnnounce == nil)
    }

    @Test func pageWithoutGreetingAnnouncesNothing() async throws {
        let env = try await DetailEnvironment()
        env.settings.showsNewDawnGreeting = true
        let model = await env.loadedDetailModel()
        #expect(env.userStore.greeting == nil)
        #expect(model.greetingToAnnounce == nil)
    }
}

@MainActor
@Suite struct GalleryDetailIntentTests {
    @Test func readIntentOpensTheReaderAtThePage() async throws {
        let env = try await DetailEnvironment()
        let model = await env.loadedDetailModel(intent: .read(page: 12))
        await pollUntil { model.destination == .reader(page: 12) }
        #expect(model.fullScreenDestination == .reader(page: 12))
    }

    @Test func commentsIntentAsksToPushTheComments() async throws {
        let env = try await DetailEnvironment()
        let model = await env.loadedDetailModel(intent: .comments(scrollTo: "5143504"))
        await pollUntil { model.destination == .comments(scrollTo: "5143504") }
        #expect(model.pushedDestination == .comments(scrollTo: "5143504"))
    }

    @Test func withoutAnIntentNothingOpens() async throws {
        let env = try await DetailEnvironment()
        let model = await env.loadedDetailModel()
        #expect(model.destination == nil)
    }

    @Test func theIntentRunsOnlyOnce() async throws {
        let env = try await DetailEnvironment()
        let model = await env.loadedDetailModel(intent: .read(page: 3))
        await pollUntil { model.destination == .reader(page: 3) }
        // Back from the reader, then the screen appears again (e.g. after popping a child).
        model.fullScreenDestination = nil
        await model.load()
        #expect(model.destination == nil)
    }
}

@MainActor
@Suite struct GalleryDetailTagTranslationTests {
    private func seedTranslation(_ env: DetailEnvironment) async throws {
        let translation = TagTranslation(
            namespace: .other, key: "non-h imageset", value: "非H图集 🐱",
            description: "Not hentai.", linksString: "[Wiki](https://example.com/wiki)"
        )
        try await env.database.replaceTagTranslations([
            StoredTagTranslation(
                key: "othernon-h imageset", translation: translation, displayValue: "非H图集 🐱", valueImageURL: nil
            )
        ])
    }

    @Test func chipsCarryKeysAndTheTranslationDetail() async throws {
        let env = try await DetailEnvironment()
        try await seedTranslation(env)
        let model = await env.loadedDetailModel()
        let chip = try #require(model.tagRows.first?.chips.first)
        #expect(chip.translationKey == "othernon-h imageset")
        #expect(chip.searchKeyword == "o:\"non-h imageset$\"")
        #expect(chip.voteKeyword == "o:non-h imageset")
        #expect(chip.detail?.description == "Not hentai.")
        #expect(chip.detail?.links == [URL(string: "https://example.com/wiki")!])
    }

    @Test func translatedTextComesFromTheServiceBySynchronousLookup() async throws {
        let env = try await DetailEnvironment()
        try await seedTranslation(env)
        env.settings.enablesTagsExtension = true
        env.settings.translatesTags = true
        let model = await env.loadedDetailModel()
        let chip = try #require(model.tagRows.first?.chips.first)
        await pollUntil { model.translation(for: chip) != nil }
        let translation = model.translation(for: chip)
        #expect(chip.content.chipText(translation: translation, showsImages: true) == "非H图集 🐱")
        #expect(chip.content.chipText(translation: translation, showsImages: false) == "非H图集 ")
        #expect(chip.content.chipText(translation: nil, showsImages: true) == "non-h imageset")
    }
}
