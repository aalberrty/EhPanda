@testable import EhFeatures
import EhModels
import Testing

@Suite struct ReaderPreviewPagingTests {
    @Test func batchSizeComesFromTheStoredLayoutOrTheLegacyDefault() {
        #expect(ReaderPreviewPaging(config: nil).batchSize == 40)
        #expect(ReaderPreviewPaging(config: .normal(rows: 4)).batchSize == 40)
        #expect(ReaderPreviewPaging(config: .normal(rows: 8)).batchSize == 80)
        #expect(ReaderPreviewPaging(config: .large(rows: 4)).batchSize == 20)
        // A layout that cannot be (zero rows) must not divide by zero.
        #expect(ReaderPreviewPaging(config: .large(rows: 0)).batchSize == 1)
    }

    @Test func previewPageOfAnIndexThatIsAMultipleOfTheBatchSize() {
        let paging = ReaderPreviewPaging(config: .normal(rows: 4))
        #expect(paging.previewPage(for: 1) == 0)
        #expect(paging.previewPage(for: 39) == 0)
        // Legacy answered 1 here, the next preview page.
        #expect(paging.previewPage(for: 40) == 0)
        #expect(PreviewConfig.normal(rows: 4).pageNumber(index: 40) == 0)
        #expect(paging.previewPage(for: 41) == 1)
        #expect(paging.previewPage(for: 80) == 1)
        #expect(paging.previewPage(for: 81) == 2)
        #expect(paging.previewPage(for: 0) == 0)

        let large = ReaderPreviewPaging(config: .large(rows: 4))
        #expect(large.previewPage(for: 20) == 0)
        #expect(large.previewPage(for: 21) == 1)
        #expect(large.previewPage(for: 200) == 9)
    }

    @Test func everyPageIsListedOnItsPreviewPage() {
        for config in [PreviewConfig.normal(rows: 4), .large(rows: 4), .normal(rows: 20)] {
            let paging = ReaderPreviewPaging(config: config)
            for index in 1...500 {
                #expect(paging.pages(onPreviewPage: paging.previewPage(for: index)).contains(index))
            }
        }
        #expect(ReaderPreviewPaging(config: .normal(rows: 4)).pages(onPreviewPage: 1) == 41...80)
    }

    @Test func learnsTheBatchSizeFromAShortFirstPreviewPage() {
        var paging = ReaderPreviewPaging(config: nil)
        do {
            let changed = paging.learn(listed: 1...20, onPreviewPage: 0, pageCount: 100)
            #expect(changed)
        }
        #expect(paging.batchSize == 20)
        #expect(paging.previewPage(for: 25) == 1)
    }

    @Test func learnsTheBatchSizeFromWhereALaterPreviewPageStarts() {
        var paging = ReaderPreviewPaging(config: .large(rows: 4))
        // Asked for the second preview page expecting 21..., got 41...
        do {
            let changed = paging.learn(listed: 41...80, onPreviewPage: 1, pageCount: 200)
            #expect(changed)
        }
        #expect(paging.batchSize == 40)

        var other = ReaderPreviewPaging(config: .normal(rows: 4))
        do {
            let changed = other.learn(listed: 61...80, onPreviewPage: 3, pageCount: 200)
            #expect(changed)
        }
        #expect(other.batchSize == 20)
    }

    @Test func keepsTheBatchSizeWhenTheResponseAgreesOrSaysNothing() {
        var paging = ReaderPreviewPaging(config: .normal(rows: 4))
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
