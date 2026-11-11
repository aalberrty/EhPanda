import EhDatabase
import EhFeatures
import EhModels
import EhNetworking
import Foundation
import Testing

@Suite struct PreviewPagingTests {
    @Test(arguments: [
        (1, 0), (39, 0), (40, 0), (41, 1), (80, 1), (81, 2), (120, 2), (121, 3)
    ])
    func normalLayoutPages(index: Int, page: Int) {
        #expect(PreviewPaging.pageNumber(forIndex: index, config: .normal(rows: 4)) == page)
    }

    @Test(arguments: [(1, 0), (20, 0), (21, 1), (40, 1), (41, 2)])
    func largeLayoutPages(index: Int, page: Int) {
        #expect(PreviewPaging.pageNumber(forIndex: index, config: .large(rows: 4)) == page)
    }

    /// The model's own method is off by one at exact multiples of the batch size; the feature
    /// does not use it.
    @Test func exactMultiplesStayOnTheirPage() {
        let config = PreviewConfig.normal(rows: 4)
        #expect(config.pageNumber(index: 40) == 1)
        #expect(PreviewPaging.pageNumber(forIndex: 40, config: config) == 0)
        #expect(PreviewPaging.indices(onPage: 0, config: config) == 1...40)
        #expect(PreviewPaging.indices(onPage: 1, config: config) == 41...80)
    }

    @Test func spriteURLsDecodeToTheirCrop() throws {
        let url = CombinedPreviewURL.url(
            plainURL: URL(string: "https://ehgt.org/a/sheet.webp")!, width: "100", height: "142", offset: "200"
        )
        let thumbnail = PreviewThumbnail(index: 3, url: url)
        #expect(thumbnail.source == .sprite(
            sheetURL: URL(string: "https://ehgt.org/a/sheet.webp")!, x: 200, width: 100, height: 142
        ))
        let plain = PreviewThumbnail(index: 4, url: URL(string: "https://ehgt.org/a/single.jpg")!)
        #expect(plain.source == .image(URL(string: "https://ehgt.org/a/single.jpg")!))
    }
}

@MainActor
@Suite struct PreviewsModelTests {
    private func makeModel(
        _ env: DetailEnvironment, pageCount: Int = 156, known: [Int: URL] = [:]
    ) -> PreviewsModel {
        env.with {
            PreviewsModel(
                gallery: DetailEnvironment.gallery, pageCount: pageCount, config: .normal(rows: 4), previewURLs: known
            )
        }
    }

    private func previewRequests(_ env: DetailEnvironment) -> [String] {
        env.requests("GET", path: DetailEnvironment.detailPath).compactMap { request in
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "p" }?.value
        }
    }

    @Test func exactMultipleOfTheBatchRequestsItsOwnPage() async throws {
        let env = try await DetailEnvironment()
        env.serveDetail()
        let model = makeModel(env)
        await model.load()

        model.thumbnailAppeared(40)
        await pollUntil { model.preview(at: 40) != nil }

        #expect(previewRequests(env) == ["0"])
        #expect(model.preview(at: 1) != nil)
    }

    @Test func newPreviewsMergeAndAreStored() async throws {
        let env = try await DetailEnvironment()
        env.serveDetail()
        let known = URL(string: "https://ehgt.org/known.jpg")!
        let model = makeModel(env, known: [1: known])
        await model.load()

        model.thumbnailAppeared(2)
        await pollUntil { model.preview(at: 2) != nil }

        #expect(model.preview(at: 1)?.source == .image(known))
        await pollUntil {
            (try? await env.database.pages(gid: DetailEnvironment.gid))?.count == 39
        }
    }

    @Test func storedPreviewsNeedNoRequest() async throws {
        let env = try await DetailEnvironment()
        try await env.database.upsertPages((41...80).map {
            GalleryPage(gid: DetailEnvironment.gid, index: $0, previewURL: URL(string: "https://ehgt.org/\($0).jpg"))
        })
        let model = makeModel(env)
        model.thumbnailAppeared(41)
        await model.load()
        #expect(model.preview(at: 41) != nil)
        #expect(env.transport.requests.isEmpty)
    }

    @Test func appearancesBeforeLoadingWaitForTheStoredPreviews() async throws {
        let env = try await DetailEnvironment()
        env.serveDetail()
        let model = makeModel(env)
        model.thumbnailAppeared(1)
        #expect(env.transport.requests.isEmpty)
        await model.load()
        await pollUntil { model.preview(at: 1) != nil }
        #expect(previewRequests(env) == ["0"])
    }

    @Test func failedPageIsReportedAndRetriedWhenShownAgain() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.path(DetailEnvironment.detailPath), reply: .error(URLError(.timedOut)))
        let model = makeModel(env)
        await model.load()
        model.thumbnailAppeared(10)
        await pollUntil { model.hasFailed(at: 10) }
        #expect(model.hasFailed(at: 40))
        #expect(!model.hasFailed(at: 41))

        // The fixture is the gallery's first preview page.
        env.serveDetail()
        model.thumbnailDisappeared(10)
        model.thumbnailAppeared(10)
        #expect(!model.hasFailed(at: 10))
        await pollUntil { model.preview(at: 10) != nil }
        #expect(previewRequests(env) == ["0", "0"])
    }

    @Test func leavingThePageCancelsItsRequest() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.path(DetailEnvironment.detailPath), reply: .suspendUntilCancelled)
        let model = makeModel(env)
        await model.load()
        model.thumbnailAppeared(90)
        await pollUntil { previewRequests(env) == ["2"] }
        model.thumbnailDisappeared(90)

        env.serveDetail()
        model.thumbnailAppeared(90)
        await pollUntil { previewRequests(env).count == 2 }
        #expect(!model.hasFailed(at: 90))
    }

    @Test func tappingAPreviewOpensTheReaderThere() async throws {
        let env = try await DetailEnvironment()
        let model = makeModel(env)
        model.openReader(at: 33)
        #expect(model.readerDestination == .reader(page: 33))
        await pollUntil { (try? await env.database.state(gid: DetailEnvironment.gid))?.readingProgress == 33 }
    }
}
