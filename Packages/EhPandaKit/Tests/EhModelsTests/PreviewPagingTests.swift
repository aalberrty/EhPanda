import EhModels
import Foundation
import Testing

@Suite struct PreviewPagingTests {
    @Test func batchSizeComesFromTheLayoutOrTheLegacyDefault() {
        #expect(PreviewPaging(config: nil).batchSize == 40)
        #expect(PreviewPaging(config: .normal(rows: 4)).batchSize == 40)
        #expect(PreviewPaging(config: .normal(rows: 8)).batchSize == 80)
        #expect(PreviewPaging(config: .large(rows: 4)).batchSize == 20)
        // A layout that cannot be (zero rows) must not divide by zero.
        #expect(PreviewPaging(config: .large(rows: 0)).batchSize == 1)
    }

    @Test(arguments: [
        (0, 0), (1, 0), (39, 0), (40, 0), (41, 1), (80, 1), (81, 2), (120, 2), (121, 3)
    ])
    func normalLayoutPages(index: Int, page: Int) {
        // Legacy answered 1 for index 40, the next preview page.
        #expect(PreviewPaging(config: .normal(rows: 4)).previewPage(for: index) == page)
    }

    @Test(arguments: [(1, 0), (20, 0), (21, 1), (40, 1), (41, 2), (200, 9)])
    func largeLayoutPages(index: Int, page: Int) {
        #expect(PreviewPaging(config: .large(rows: 4)).previewPage(for: index) == page)
    }

    @Test func learnsTheBatchSizeFromAShortFirstPreviewPage() {
        var paging = PreviewPaging(config: nil)
        do {
            let changed = paging.learn(listed: 1...20, onPreviewPage: 0, pageCount: 100)
            #expect(changed)
        }
        #expect(paging.batchSize == 20)
        #expect(paging.previewPage(for: 25) == 1)
    }

    @Test func learnsTheBatchSizeFromWhereALaterPreviewPageStarts() {
        var paging = PreviewPaging(config: .large(rows: 4))
        // Asked for the second preview page expecting 21..., got 41...
        do {
            let changed = paging.learn(listed: 41...80, onPreviewPage: 1, pageCount: 200)
            #expect(changed)
        }
        #expect(paging.batchSize == 40)

        var other = PreviewPaging(config: .normal(rows: 4))
        do {
            let changed = other.learn(listed: 61...80, onPreviewPage: 3, pageCount: 200)
            #expect(changed)
        }
        #expect(other.batchSize == 20)
    }

    @Test func keepsTheBatchSizeWhenTheResponseAgreesOrSaysNothing() {
        var paging = PreviewPaging(config: .normal(rows: 4))
        do {
            let changed = paging.learn(listed: 1...40, onPreviewPage: 0, pageCount: 100)
            #expect(!changed)
        }
        do {
            let changed = paging.learn(listed: 41...80, onPreviewPage: 1, pageCount: 100)
            #expect(!changed)
        }
        // The whole gallery fits on the first preview page: nothing to learn.
        do {
            let changed = paging.learn(listed: 1...12, onPreviewPage: 0, pageCount: 12)
            #expect(!changed)
        }
        do {
            let changed = paging.learn(listed: [Int](), onPreviewPage: 0, pageCount: 100)
            #expect(!changed)
        }
        // A later preview page that starts at 1 is not a later preview page.
        do {
            let changed = paging.learn(listed: 1...40, onPreviewPage: 2, pageCount: 100)
            #expect(!changed)
        }
        #expect(paging.batchSize == 40)
    }
}

@Suite struct PreviewPageTests {
    private func url(_ string: String) -> URL { URL(string: string)! }

    @Test func listsEveryIndexOfEitherHalf() {
        let listed = PreviewPage(
            previewURLs: [1: url("https://ehgt.org/1.jpg"), 2: url("https://ehgt.org/2.jpg")],
            pageURLs: [2: url("https://e-hentai.org/s/a/1-2"), 3: url("https://e-hentai.org/s/b/1-3")]
        )
        #expect(listed.indices == [1, 2, 3])
        #expect(!listed.isEmpty)
        #expect(PreviewPage().isEmpty)
    }
}

@Suite struct CombinedPreviewURLTests {
    private func url(_ string: String) -> URL { URL(string: string)! }
    private var sheet: URL { url("https://ehgt.org/m/002345/2345678-00.jpg") }

    @Test func appendsTileGeometry() {
        let combined = CombinedPreviewURL.url(plainURL: sheet, width: "100", height: "142", offset: "-200")
        #expect(combined.absoluteString
            == "https://ehgt.org/m/002345/2345678-00.jpg?ehpandaWidth=100&ehpandaHeight=142&ehpandaOffset=-200")
    }

    @Test func parsesWhatItBuilds() {
        let combined = CombinedPreviewURL.url(plainURL: sheet, width: "100", height: "142", offset: "-200")
        #expect(CombinedPreviewURL.parse(combined)
            == CombinedPreviewURL(plainURL: sheet, width: 100, height: 142, offset: -200))
    }

    @Test func parseDropsTheWholeQuery() {
        let combined = url("https://ehgt.org/a.jpg?v=2&ehpandaOffset=0&ehpandaHeight=10&ehpandaWidth=20")
        #expect(CombinedPreviewURL.parse(combined)
            == CombinedPreviewURL(plainURL: url("https://ehgt.org/a.jpg"), width: 20, height: 10, offset: 0))
    }

    @Test(arguments: [
        "https://ehgt.org/a.jpg",
        "https://ehgt.org/a.jpg?ehpandaWidth=20&ehpandaHeight=10",
        "https://ehgt.org/a.jpg?ehpandaWidth=20&ehpandaHeight=10&ehpandaOffset=x",
        "https://ehgt.org/a.jpg?ehpandaWidth=20.5&ehpandaHeight=10&ehpandaOffset=0"
    ])
    func parseRejectsIncompleteURLs(string: String) {
        #expect(CombinedPreviewURL.parse(url(string)) == nil)
    }
}
