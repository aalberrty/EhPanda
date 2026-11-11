@testable import EhDatabase
import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

/// Opening a gallery: what the screen waits for, what it writes, and which answer wins when
/// two are on their way.
@MainActor
@Suite struct GalleryDetailOpeningTests {
    private func storedDetail(title: String) -> GalleryDetail {
        GalleryDetail(
            gid: DetailEnvironment.gid, title: title, isFavorited: false, visibility: .yes, rating: 3,
            userRating: 2.5, ratingCount: 1, category: .nonH, language: .japanese, uploader: "Stored uploader",
            postedDate: .now, coverURL: nil, favoritedCount: 1, pageCount: 156, sizeCount: 1, sizeType: "MiB",
            torrentCount: 0
        )
    }

    /// The detail fixture with its second comment repeated `count` times, each under its own id.
    private func pageWithManyComments(_ count: Int) throws -> Data {
        let fixture = try Fixture.string("Parser/Gallery/GalleryDetail.html")
        let start = try #require(fixture.range(of: #"<a name="c5143504"></a>"#))
        let end = try #require(fixture.range(of: #"<a name="c"#, range: start.upperBound..<fixture.endIndex))
        let comment = String(fixture[start.lowerBound..<end.lowerBound])
        let more = (1...count)
            .map { comment.replacingOccurrences(of: "5143504", with: String(9_000_000 + $0)) }
            .joined()
        return Data(fixture.replacingCharacters(in: end.lowerBound..<end.lowerBound, with: more).utf8)
    }

    @Test func theRequestGoesOutWithoutWaitingForWhatIsStored() async throws {
        let env = try await DetailEnvironment()
        try await env.database.saveDetail(
            storedDetail(title: "Stored title"), state: GalleryState(gid: DetailEnvironment.gid)
        )
        env.serveDetail()
        let model = env.makeDetailModel()
        var loading: Task<Void, Never>?

        // Nothing stored can be read while the database is held. The page is asked for,
        // arrives and is shown all the same.
        try await env.database.whileWriterIsBusy {
            loading = Task { await model.load() }
            await pollUntil { model.detail?.title == "[Artist] mks" && model.comments.count == 10 }
            #expect(env.detailFetchCount == 1)
            #expect(model.loadingState == .idle)
        }
        await loading?.value

        // What is stored was read after the page arrived. It is older and is not applied.
        #expect(model.detail?.title == "[Artist] mks")
        #expect(model.comments.count == 10)
        #expect(model.previews.count == 40)
        #expect(try await env.database.detail(gid: DetailEnvironment.gid)?.title == "[Artist] mks")
    }

    @Test func aFetchedPageIsStoredInOneTransaction() async throws {
        let env = try await DetailEnvironment()
        env.serveDetail()
        let model = env.makeDetailModel()

        let commits = try await env.database.commitCount { await model.load() }

        // The visit recorded in the history, and the page: detail, tags, comments, preview
        // layout and the forty pages its first preview page lists.
        #expect(commits == 2)
        #expect(try await env.database.pages(gid: DetailEnvironment.gid).count == 40)
        #expect(try await env.database.state(gid: DetailEnvironment.gid)?.comments.count == 10)
    }

    /// The loading state goes idle before the comments are prepared, so the page can be
    /// fetched again (after a vote, say) and that answer applied while the first answer's
    /// comments are still being prepared. They must not replace the newer ones.
    @Test func theCommentsOfASupersededFetchAreDropped() async throws {
        let env = try await DetailEnvironment()
        // Thousands of comments take long to prepare; the fixture's ten do not.
        env.transport.on(.path(DetailEnvironment.detailPath), replies: [
            .body(try pageWithManyComments(4000)), .fixture("Parser/Gallery/GalleryDetail.html")
        ])
        let model = env.makeDetailModel()
        let loading = Task { await model.load() }
        await pollUntil { model.detail != nil && model.loadingState == .idle }

        model.refetch()
        await pollUntil { env.detailFetchCount == 2 && model.loadingState == .idle && model.comments.count == 10 }
        await loading.value

        #expect(model.comments.count == 10)
        #expect(try await env.database.state(gid: DetailEnvironment.gid)?.comments.count == 10)
    }
}
