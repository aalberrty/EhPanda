import CoreGraphics
import Testing
@testable import EhFeatures

@Suite struct ReaderPrefetchWindowTests {
    @Test func reachMatchesLegacyRanges() {
        // Legacy reached from `page - 2 - limit / 2` to `page + 2 + limit / 2`.
        #expect(ReaderPrefetchWindow.reach(forLimit: 10) == 7)
        #expect(ReaderPrefetchWindow.reach(forLimit: 6) == 5)
        #expect(ReaderPrefetchWindow.reach(forLimit: 18) == 11)
        #expect(ReaderPrefetchWindow.reach(forLimit: 0) == 2)
        #expect(ReaderPrefetchWindow.reach(forLimit: -4) == 2)
    }

    @Test func rangeExtendsBothWaysAndIsClamped() {
        #expect(ReaderPrefetchWindow.range(visible: 50...51, pageCount: 200, limit: 10) == 43...58)
        #expect(ReaderPrefetchWindow.range(visible: 1...1, pageCount: 200, limit: 10) == 1...8)
        #expect(ReaderPrefetchWindow.range(visible: 199...200, pageCount: 200, limit: 10) == 192...200)
        #expect(ReaderPrefetchWindow.range(visible: 2...3, pageCount: 4, limit: 18) == 1...4)
        #expect(ReaderPrefetchWindow.range(visible: 1...1, pageCount: 0, limit: 10) == nil)
    }

    @Test func rangeToleratesVisiblePagesOutsideTheGallery() {
        #expect(ReaderPrefetchWindow.range(visible: 300...301, pageCount: 20, limit: 10) == 20...20)
    }

    @Test func prioritizedStartsWithVisibleThenAlternatesAheadAndBehind() {
        let pages = ReaderPrefetchWindow.prioritized(3...10, around: 5...6)
        #expect(pages == [5, 6, 7, 4, 8, 3, 9, 10])
    }

    @Test func prioritizedCoversTheWholeRangeOnce() {
        for visible in [1...1, 7...8, 20...20] {
            guard let range = ReaderPrefetchWindow.range(visible: visible, pageCount: 20, limit: 10) else {
                Issue.record("no range")
                continue
            }
            let pages = ReaderPrefetchWindow.prioritized(range, around: visible)
            #expect(pages.sorted() == Array(range))
            #expect(Array(pages.prefix(visible.count)) == Array(visible))
        }
    }

    @Test func changesListPagesEnteringAndLeaving() {
        let moved = ReaderPrefetchWindow.changes(from: 3...8, to: 5...10)
        #expect(moved.added == [9, 10])
        #expect(moved.removed == [3, 4])

        let jumped = ReaderPrefetchWindow.changes(from: 1...3, to: 40...41)
        #expect(jumped.added == [40, 41])
        #expect(jumped.removed == [1, 2, 3])

        let started = ReaderPrefetchWindow.changes(from: nil, to: 1...3)
        #expect(started.added == [1, 2, 3])
        #expect(started.removed.isEmpty)

        let stopped = ReaderPrefetchWindow.changes(from: 1...3, to: nil)
        #expect(stopped.added.isEmpty)
        #expect(stopped.removed == [1, 2, 3])

        let same = ReaderPrefetchWindow.changes(from: 4...9, to: 4...9)
        #expect(same.added.isEmpty && same.removed.isEmpty)
    }
}
