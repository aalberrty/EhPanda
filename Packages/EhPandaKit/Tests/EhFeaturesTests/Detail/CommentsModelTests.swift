import EhFeatures
import EhModels
import EhNetworking
import Foundation
import Testing

@MainActor
@Suite struct CommentsModelTests {
    private func makeModel(
        _ env: DetailEnvironment, scrollTo commentID: String? = nil
    ) async -> (GalleryDetailModel, CommentsModel) {
        let detail = await env.loadedDetailModel()
        let comments = env.with { CommentsModel(detail: detail, scrollTo: commentID, intents: env.intents) }
        return (detail, comments)
    }

    private func otherGallery(gid: String = "999") -> Gallery {
        Gallery(
            gid: gid, token: "tok", title: "Other", rating: 0, tags: [], category: .manga, pageCount: 20,
            postedDate: .now, coverURL: nil, galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/tok/")
        )
    }

    // MARK: Rendering data

    @Test func commentsComeFromTheDetailWithPreparedBodies() async throws {
        let env = try await DetailEnvironment()
        let (_, model) = await makeModel(env)
        #expect(model.comments.count == 10)
        let first = try #require(model.comments.first)
        #expect(first.author == "Pokom")
        guard case .text(let text) = try #require(first.blocks.first) else {
            Issue.record("Expected text")
            return
        }
        let links = text.runs.compactMap(\.link)
        #expect(links.map(\.absoluteString) == [
            "https://www.pixiv.net/users/750220", "https://mks.booth.pm/", "https://twitter.com/mks_fStD"
        ])
    }

    @Test func blocksKeepEveryKindOfRun() {
        let link = URL(string: "https://e-hentai.org/g/1/a/")!
        let image = URL(string: "https://example.com/a.jpg")!
        let comment = GalleryComment(
            votedUp: false, votedDown: false, votable: true, editable: false, score: "+1", author: "A \u{00A0} ",
            contents: [
                CommentContent(type: .plainText, text: "see"),
                CommentContent(type: .linkedText, text: "this", link: link),
                CommentContent(type: .singleLink, link: link),
                CommentContent(type: .linkedImg, link: link, imgURL: image),
                CommentContent(type: .doubleImg, imgURL: image, secondImgURL: image)
            ],
            commentID: "1", commentDate: .now
        )
        let item = CommentItem(comment: comment, detector: nil)
        #expect(item.author == "A")
        #expect(item.summary == "see this")
        #expect(item.blocks.count == 5)
        #expect(item.blocks[3] == .images([CommentImage(imageURL: image, link: link)]))
        #expect(item.blocks[4] == .images([
            CommentImage(imageURL: image, link: nil), CommentImage(imageURL: image, link: nil)
        ]))
        if case .text(let linked) = item.blocks[1] {
            #expect(linked.runs.first?.link == link)
        } else {
            Issue.record("Expected linked text")
        }
    }

    // MARK: Composing and voting

    @Test func composingNeedsLogin() async throws {
        let env = try await DetailEnvironment()
        let (_, model) = await makeModel(env)
        model.compose()
        #expect(model.composer == nil)
    }

    @Test func editPrefillsAndSubmitPostsTheEdit() async throws {
        let env = try await DetailEnvironment()
        env.logIn()
        env.transport.on(.method("POST"), reply: .status(200))
        let (detail, model) = await makeModel(env)
        model.compose()
        #expect(model.composer == .new)

        let comment = GalleryComment(
            votedUp: false, votedDown: false, votable: false, editable: true, score: nil, author: "Me",
            contents: [CommentContent(type: .plainText, text: "Old")], commentID: "77", commentDate: .now
        )
        model.edit(CommentItem(comment: comment, detector: nil))
        #expect(model.composer == .edit(commentID: "77", text: "Old"))
        #expect(model.composer?.initialText == "Old")

        model.submit("New", for: .edit(commentID: "77", text: "Old"))
        #expect(model.composer == nil)
        await pollUntil { detail.feedback?.isSuccess == true }
        #expect(formBody(try #require(env.requests("POST", path: DetailEnvironment.detailPath).first))
            .contains("edit_comment=77"))
    }

    @Test func votingNeedsAVotableComment() async throws {
        let env = try await DetailEnvironment()
        env.logIn()
        env.transport.on(.method("POST"), reply: .status(200))
        let (detail, model) = await makeModel(env)
        let uploaderComment = try #require(model.comments.first)
        model.vote(uploaderComment, up: true)
        let votable = try #require(model.comments.first { $0.comment.votable })
        model.vote(votable, up: false)
        await pollUntil { detail.feedback?.isSuccess == true }
        let votes = env.requests("POST", path: "/api.php").map(jsonBody)
        #expect(votes.count == 1)
        #expect(votes.first?["comment_id"] as? Int == Int(votable.id))
        #expect(votes.first?["comment_vote"] as? Int == -1)
    }

    // MARK: Scrolling to a comment

    @Test func scrollsToAndHighlightsTheTargetOnce() async throws {
        let env = try await DetailEnvironment()
        let (_, model) = await makeModel(env, scrollTo: "5143504")
        #expect(model.isScrollTargetReady)
        await model.scrollToTarget()
        #expect(model.scrollTarget == nil)
        #expect(model.highlightedCommentID == nil)
        #expect(model.highlightOpacity == 1)
        #expect(!model.isScrollTargetReady)
    }

    @Test func missingTargetWaits() async throws {
        let env = try await DetailEnvironment()
        let (_, model) = await makeModel(env, scrollTo: "404")
        #expect(!model.isScrollTargetReady)
        await model.scrollToTarget()
        #expect(model.scrollTarget == nil)
    }

    // MARK: Links

    @Test func linksOutsideTheSiteOpenExternally() async throws {
        let env = try await DetailEnvironment()
        let (_, model) = await makeModel(env)
        model.openLink(URL(string: "https://example.com/page")!)
        await pollUntil { env.openedURLs.all.count == 1 }
        #expect(model.linkedGallery == nil)
    }

    @Test func storedGalleryOpensWithoutARequest() async throws {
        let env = try await DetailEnvironment()
        let (_, model) = await makeModel(env)
        let other = otherGallery()
        try await env.database.recordOpened(other)
        let requestsBefore = env.transport.requests.count

        model.openLink(URL(string: "https://e-hentai.org/s/0123456789/999-5")!)
        await pollUntil { model.linkedGallery != nil }

        #expect(model.linkedGallery == other)
        #expect(env.transport.requests.count == requestsBefore)
        #expect(env.intents.take(for: "999") == .read(page: 5))
        await pollUntil { (try? await env.database.state(gid: "999"))?.readingProgress == 5 }
    }

    @Test func unknownGalleryIsResolvedThenPushedWithTheCommentIntent() async throws {
        let env = try await DetailEnvironment()
        let (_, model) = await makeModel(env)

        // Any gallery page parses; the gallery takes its gid and token from the link.
        env.transport.on(.path("/g/31338/cafe/"), reply: .fixture("Parser/Gallery/GalleryDetail.html"))

        model.openLink(URL(string: "https://e-hentai.org/g/31338/cafe/#c5143504")!)
        await pollUntil { model.linkedGallery != nil }

        let gallery = try #require(model.linkedGallery)
        #expect(gallery.gid == "31338")
        #expect(gallery.token == "cafe")
        #expect(gallery.title == "[Artist] mks")
        #expect(model.linkState == nil)
        #expect(env.intents.take(for: "31338") == .comments(scrollTo: "5143504"))
        #expect(env.requests("GET", path: "/g/31338/cafe/").count == 1)
    }

    @Test func resolutionFailureShowsTheError() async throws {
        let env = try await DetailEnvironment()
        let (_, model) = await makeModel(env)
        env.transport.on(.path("/g/31337/beef/"), reply: .error(URLError(.timedOut)))

        model.openLink(URL(string: "https://e-hentai.org/g/31337/beef/")!)
        await pollUntil { model.linkState == .failed(.networkingFailed) }

        #expect(model.linkedGallery == nil)
        model.dismissLinkState()
        #expect(model.linkState == nil)
    }
}
