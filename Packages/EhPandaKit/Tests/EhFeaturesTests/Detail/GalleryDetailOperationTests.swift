import EhFeatures
import EhModels
import EhNetworking
import Foundation
import Testing

@MainActor
@Suite struct GalleryDetailOperationTests {
    /// A logged-in model that has loaded the fixture, with the site accepting every POST.
    private func loggedInModel(_ env: DetailEnvironment) async -> GalleryDetailModel {
        env.logIn()
        env.transport.on(.method("POST"), reply: .status(200))
        let model = await env.loadedDetailModel()
        #expect(model.isLoggedIn)
        return model
    }

    /// Waits for the operation's haptic and the page fetched again after it.
    private func expectSuccessAndRefetch(_ model: GalleryDetailModel, _ env: DetailEnvironment) async {
        await pollUntil { model.feedback?.isSuccess == true }
        await pollUntil { env.detailFetchCount == 2 && model.loadingState == .idle }
    }

    @Test func favoriteAddsToTheChosenFolderThenRefetches() async throws {
        let env = try await DetailEnvironment()
        let model = await loggedInModel(env)
        model.favorite(category: 3)
        await expectSuccessAndRefetch(model, env)
        let request = try #require(env.requests("POST", path: "/gallerypopups.php").first)
        #expect(request.url?.query?.contains("act=addfav") == true)
        #expect(formBody(request).contains("favcat=3"))
    }

    @Test func unfavoriteRemovesThenRefetches() async throws {
        let env = try await DetailEnvironment()
        let model = await loggedInModel(env)
        model.unfavorite()
        await expectSuccessAndRefetch(model, env)
        let request = try #require(env.requests("POST", path: "/favorites.php").first)
        #expect(formBody(request).contains("modifygids%5B%5D=2725078"))
    }

    @Test func rateSendsHalfStarsWithTheAPIKeyThenHidesTheStars() async throws {
        let env = try await DetailEnvironment()
        let model = await loggedInModel(env)
        model.toggleRatingControl()
        #expect(model.showsRatingControl)
        model.rate(7)
        #expect(model.userRating == 7)
        #expect(model.ratingCommitCount == 1)
        await expectSuccessAndRefetch(model, env)
        await pollUntil { !model.showsRatingControl }
        let json = jsonBody(try #require(env.requests("POST", path: "/api.php").first))
        #expect(json["method"] as? String == "rategallery")
        #expect(json["rating"] as? Int == 7)
        #expect(json["apiuid"] as? Int == 1234567)
        #expect(json["apikey"] as? String == "000000000000000000")
        #expect(json["gid"] as? Int == 2725078)
    }

    @Test func postAndEditCommentPostToTheGallery() async throws {
        let env = try await DetailEnvironment()
        let model = await loggedInModel(env)
        model.postComment("Nice")
        await expectSuccessAndRefetch(model, env)
        #expect(formBody(try #require(env.requests("POST", path: DetailEnvironment.detailPath).first))
            == "commenttext_new=Nice")

        model.editComment(id: "42", text: "Edited")
        await pollUntil { env.requests("POST", path: DetailEnvironment.detailPath).count == 2 }
        let edit = formBody(env.requests("POST", path: DetailEnvironment.detailPath)[1])
        #expect(edit.contains("edit_comment=42"))
        #expect(edit.contains("commenttext_edit=Edited"))
    }

    @Test func emptyCommentIsNotSent() async throws {
        let env = try await DetailEnvironment()
        let model = await loggedInModel(env)
        model.postComment("")
        try await Task.sleep(for: .milliseconds(50))
        #expect(env.requests("POST", path: DetailEnvironment.detailPath).isEmpty)
    }

    @Test func voteCommentUsesTheAPI() async throws {
        let env = try await DetailEnvironment()
        let model = await loggedInModel(env)
        model.voteComment(id: "5143504", vote: -1)
        await expectSuccessAndRefetch(model, env)
        let json = jsonBody(try #require(env.requests("POST", path: "/api.php").first))
        #expect(json["method"] as? String == "votecomment")
        #expect(json["comment_id"] as? Int == 5143504)
        #expect(json["comment_vote"] as? Int == -1)
    }

    @Test func voteTagSendsTheVoteKeyword() async throws {
        let env = try await DetailEnvironment()
        let model = await loggedInModel(env)
        let chip = try #require(model.tagRows.first?.chips.first)
        #expect(!chip.hasVote)
        model.voteTag(chip, vote: 1)
        await expectSuccessAndRefetch(model, env)
        let json = jsonBody(try #require(env.requests("POST", path: "/api.php").first))
        #expect(json["method"] as? String == "taggallery")
        #expect(json["tags"] as? String == "o:non-h imageset")
        #expect(json["vote"] as? Int == 1)
    }

    @Test func failureGivesAnErrorHapticAndNoRefetch() async throws {
        let env = try await DetailEnvironment()
        env.logIn()
        let model = await env.loadedDetailModel()
        env.transport.on(.method("POST"), reply: .error(URLError(.notConnectedToInternet)))
        model.favorite(category: 0)
        await pollUntil { model.feedback?.kind == .failure }
        #expect(env.detailFetchCount == 1)
    }

    @Test func nonNumericMemberIDSkipsAPIOperationsSilently() async throws {
        let env = try await DetailEnvironment()
        env.logIn(memberID: "not-a-number")
        env.transport.on(.method("POST"), reply: .status(200))
        let model = await env.loadedDetailModel()
        model.rate(6)
        let chip = try #require(model.tagRows.first?.chips.first)
        model.voteTag(chip, vote: -1)
        model.voteComment(id: "5143504", vote: 1)
        try await Task.sleep(for: .milliseconds(50))
        #expect(env.requests("POST", path: "/api.php").isEmpty)
        #expect(model.feedback == nil)
    }
}

@MainActor
@Suite struct GalleryDetailLoginGatingTests {
    @Test func loggedOutUserCannotOperate() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.method("POST"), reply: .status(200))
        let model = await env.loadedDetailModel()
        #expect(!model.isLoggedIn)
        #expect(!model.canOpenArchives)

        model.favorite(category: 1)
        model.unfavorite()
        model.postComment("Hi")
        model.toggleRatingControl()
        model.rate(8)
        let chip = try #require(model.tagRows.first?.chips.first)
        model.voteTag(chip, vote: 1)
        model.showPostComment()
        model.showArchives()
        try await Task.sleep(for: .milliseconds(50))

        #expect(env.transport.requests.allSatisfy { ($0.httpMethod ?? "GET") == "GET" })
        #expect(!model.showsRatingControl)
        #expect(model.destination == nil)
    }

    @Test func loggedInUserCanOpenArchivesAndComposer() async throws {
        let env = try await DetailEnvironment()
        env.logIn()
        let model = await env.loadedDetailModel()
        #expect(model.canOpenArchives)
        model.showArchives()
        #expect(model.destination == .archives(
            archiveURL: URL(string: "https://e-hentai.org/archiver.php?gid=3103480&token=0000000000")!
        ))
        model.showPostComment()
        #expect(model.destination == .postComment)
    }

    @Test func torrentsNeedTorrents() async throws {
        let env = try await DetailEnvironment()
        let model = await env.loadedDetailModel()
        #expect(model.torrentCount == 1)
        model.showTorrents()
        #expect(model.destination == .torrents)
    }

    @Test func menuIsDisabledUntilLoaded() async throws {
        let env = try await DetailEnvironment()
        let model = env.makeDetailModel()
        #expect(!model.isMenuEnabled)
        env.serveDetail()
        await model.load()
        #expect(model.isMenuEnabled)
    }
}

@MainActor
@Suite struct GalleryDetailDestinationTests {
    @Test func previewTapStoresTheReadingProgressAndOpensTheReader() async throws {
        let env = try await DetailEnvironment()
        let model = await env.loadedDetailModel()
        model.openReader(page: 9)
        #expect(model.fullScreenDestination == .reader(page: 9))
        #expect(model.sheetDestination == nil)
        await pollUntil { (try? await env.database.state(gid: DetailEnvironment.gid))?.readingProgress == 9 }
    }

    @Test func dismissingAPresentationOnlyClearsItsOwnKind() async throws {
        let env = try await DetailEnvironment()
        let model = env.makeDetailModel()
        model.destination = .previews
        model.sheetDestination = nil
        #expect(model.destination == .previews)
        model.pushedDestination = nil
        #expect(model.destination == nil)
    }
}

@Suite struct DetailSearchKeywordTests {
    private let tag = GalleryTag(rawNamespace: "female", contents: [])
    private let temp = GalleryTag(rawNamespace: "temp", contents: [])

    private func content(_ text: String, _ namespace: String = "female") -> GalleryTag.Content {
        .init(rawNamespace: namespace, text: text, isVotedUp: false, isVotedDown: false, backgroundColor: nil)
    }

    @Test func tagKeywords() {
        #expect(DetailSearchKeyword.tag(content("glasses"), in: tag) == "f:glasses$")
        #expect(DetailSearchKeyword.tag(content("big breasts"), in: tag) == "f:\"big breasts$\"")
        #expect(DetailSearchKeyword.tag(content("lorem", "temp"), in: temp) == "lorem$")
    }

    @Test func uploaderKeyword() {
        #expect(DetailSearchKeyword.uploader("Pokom") == "uploader:\"Pokom\"")
    }

    @Test func similarGalleryKeywordIsTheTrimmedTitle() {
        let detail = GalleryDetail(
            gid: "1", title: "[Group (Artist)] Title (Parody) [English] | Other", isFavorited: false,
            visibility: .yes, rating: 0, userRating: 0, ratingCount: 0, category: .doujinshi,
            language: .english, uploader: "", postedDate: .now, coverURL: nil, favoritedCount: 0,
            pageCount: 1, sizeCount: 0, sizeType: "", torrentCount: 0
        )
        #expect(DetailSearchKeyword.similar(to: detail) == detail.trimmedTitle)
        #expect(DetailSearchKeyword.similar(to: detail) == "Title")
    }
}
