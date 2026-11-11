import CoreGraphics
import Testing
@testable import EhFeatures

@Suite struct ReaderStripLayoutTests {
    /// Four pages 100 points wide: a square, an unknown one, a 1:2 portrait and a 2:1 landscape.
    private func makeLayout(gap: CGFloat = 10) -> ReaderStripLayout {
        let ratios: [CGFloat?] = [1, nil, 0.5, 2]
        return ReaderStripLayout(pageCount: 4, width: 100, gap: gap, displayScale: 2) { ratios[$0 - 1] }
    }

    @Test func pagesAreStackedWithGaps() {
        let layout = makeLayout()
        #expect(layout.frame(ofPage: 1) == CGRect(x: 0, y: 0, width: 100, height: 100))
        // Unknown ratio: 100 / 0.7 = 142.857…, rounded to half points at 2x.
        #expect(layout.frame(ofPage: 2) == CGRect(x: 0, y: 110, width: 100, height: 143))
        #expect(layout.frame(ofPage: 3) == CGRect(x: 0, y: 263, width: 100, height: 200))
        #expect(layout.frame(ofPage: 4) == CGRect(x: 0, y: 473, width: 100, height: 50))
        #expect(layout.contentHeight == 523)
        #expect(layout.frame(ofPage: 0) == .zero)
        #expect(layout.frame(ofPage: 5) == .zero)
    }

    @Test func heightsAreRoundedToPixels() {
        let layout = ReaderStripLayout(pageCount: 1, width: 100, gap: 0, displayScale: 3) { _ in 0.7 }
        // 142.857… → 428.57 px → 429 px → 143 pt.
        #expect(layout.frame(ofPage: 1).height == 143)
        let fine = ReaderStripLayout(pageCount: 1, width: 101, gap: 0, displayScale: 2) { _ in 0.7 }
        // 144.2857… → 288.57 px → 289 px → 144.5 pt.
        #expect(fine.frame(ofPage: 1).height == 144.5)
    }

    @Test func invalidRatiosFallBackToThePlaceholderShape() {
        for ratio in [0, -1, CGFloat.infinity, CGFloat.nan] {
            let layout = ReaderStripLayout(pageCount: 1, width: 70, gap: 0, displayScale: 1) { _ in ratio }
            #expect(layout.frame(ofPage: 1).height == 100)
        }
    }

    @Test func pageLookupTreatsAGapAsPartOfThePageAbove() {
        let layout = makeLayout()
        #expect(layout.page(atY: -50) == 1)
        #expect(layout.page(atY: 0) == 1)
        #expect(layout.page(atY: 99.5) == 1)
        #expect(layout.page(atY: 105) == 1)
        #expect(layout.page(atY: 110) == 2)
        #expect(layout.page(atY: 262) == 2)
        #expect(layout.page(atY: 263) == 3)
        #expect(layout.page(atY: 473) == 4)
        #expect(layout.page(atY: 10_000) == 4)
    }

    @Test func pageLookupOnAnEmptyStripIsNil() {
        let layout = ReaderStripLayout(pageCount: 0, width: 100, gap: 0, displayScale: 2) { _ in nil }
        #expect(layout.page(atY: 0) == nil)
        #expect(layout.pages(fromY: 0, toY: 100) == nil)
        #expect(layout.currentPage(viewportMinY: 0, viewportHeight: 100) == nil)
        #expect(layout.contentHeight == 0)
    }

    @Test func bandLookupFindsOverlappingPages() {
        let layout = makeLayout()
        #expect(layout.pages(fromY: 0, toY: 50) == 1...1)
        #expect(layout.pages(fromY: 50, toY: 120) == 1...2)
        // Starts in the gap below page 1.
        #expect(layout.pages(fromY: 104, toY: 300) == 2...3)
        #expect(layout.pages(fromY: -200, toY: 2_000) == 1...4)
        #expect(layout.pages(fromY: 600, toY: 700) == 4...4)
    }

    @Test func bandLookupAgreesWithABruteForceScan() {
        let ratios: [CGFloat?] = [0.7, 1.4, nil, 0.2, 0.7, 3, 0.66, nil, 0.71]
        let layout = ReaderStripLayout(pageCount: ratios.count, width: 320, gap: 5, displayScale: 3) { ratios[$0 - 1] }
        var y: CGFloat = -40
        while y < layout.contentHeight + 40 {
            let band = y...(y + 500)
            let expected = (1...ratios.count).filter { page in
                let frame = layout.frame(ofPage: page)
                return frame.maxY > band.lowerBound && frame.minY <= band.upperBound
            }
            if let first = expected.first, let last = expected.last {
                #expect(layout.pages(fromY: band.lowerBound, toY: band.upperBound) == first...last, "y \(y)")
            }
            y += 37
        }
    }

    @Test func learningARatioRestacksEverythingBelow() {
        var layout = makeLayout()
        let delta = layout.setAspectRatio(0.5, forPage: 2)
        #expect(delta == 57)
        #expect(layout.frame(ofPage: 1) == CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(layout.frame(ofPage: 2) == CGRect(x: 0, y: 110, width: 100, height: 200))
        #expect(layout.frame(ofPage: 3).minY == 320)
        #expect(layout.frame(ofPage: 4).minY == 530)
        #expect(layout.contentHeight == 580)
        #expect(layout.setAspectRatio(0.5, forPage: 2) == 0)
        #expect(layout.setAspectRatio(0.5, forPage: 9) == 0)
    }

    @Test func aPageAboveTheViewportMovesTheScrollPositionWithIt() {
        // Page 2 starts at 110 and grows by 57 while the viewport starts at 300, inside page 3.
        #expect(ReaderStripLayout.scrollAdjustment(forHeightDelta: 57, pageMinY: 110, viewportMinY: 300) == 57)
        // Straddling the top edge still keeps the bottom of the page where it was.
        #expect(ReaderStripLayout.scrollAdjustment(forHeightDelta: -30, pageMinY: 110, viewportMinY: 150) == -30)
        // A page that starts inside or below the viewport keeps its top edge.
        #expect(ReaderStripLayout.scrollAdjustment(forHeightDelta: 57, pageMinY: 110, viewportMinY: 110) == 0)
        #expect(ReaderStripLayout.scrollAdjustment(forHeightDelta: 57, pageMinY: 400, viewportMinY: 300) == 0)
    }

    @Test func adjustingKeepsTheVisiblePageInPlace() {
        var layout = makeLayout()
        let viewportMinY: CGFloat = 300
        let before = layout.frame(ofPage: 3).minY - viewportMinY
        let pageMinY = layout.frame(ofPage: 2).minY
        let delta = layout.setAspectRatio(0.25, forPage: 2)
        let adjusted = viewportMinY + ReaderStripLayout.scrollAdjustment(
            forHeightDelta: delta, pageMinY: pageMinY, viewportMinY: viewportMinY
        )
        #expect(layout.frame(ofPage: 3).minY - adjusted == before)
    }

    @Test func anchorSurvivesAWidthChange() throws {
        var layout = makeLayout()
        // A quarter of the way down page 3 (263 + 50).
        let anchor = try #require(layout.anchor(atY: 313))
        #expect(anchor == ReaderStripLayout.Anchor(page: 3, fraction: 0.25))
        layout.setWidth(200)
        #expect(layout.frame(ofPage: 3).height == 400)
        #expect(layout.y(for: anchor) == layout.frame(ofPage: 3).minY + 100)
    }

    @Test func anchorInAGapOrOutsideTheStripIsClampedToThePage() throws {
        let layout = makeLayout()
        #expect(try #require(layout.anchor(atY: 105)) == ReaderStripLayout.Anchor(page: 1, fraction: 1))
        #expect(try #require(layout.anchor(atY: -20)) == ReaderStripLayout.Anchor(page: 1, fraction: 0))
        #expect(try #require(layout.anchor(atY: 9_999)) == ReaderStripLayout.Anchor(page: 4, fraction: 1))
    }

    @Test func gapChangesRestackWithoutChangingHeights() {
        var layout = makeLayout()
        layout.setGap(0)
        #expect(layout.frame(ofPage: 2) == CGRect(x: 0, y: 100, width: 100, height: 143))
        #expect(layout.contentHeight == 493)
        layout.setGap(-5)
        #expect(layout.gap == 0)
    }

    @Test func scrollingToAPageCentresItUnlessItIsTallerThanTheViewport() {
        let layout = makeLayout()
        // Page 4 is 50 tall at 473: centred in a 300 viewport would be 348, but the strip ends at 523.
        #expect(layout.offset(forPage: 4, viewportHeight: 300) == 223)
        // Page 2 (110...253) centred in a 300 viewport.
        #expect(layout.offset(forPage: 2, viewportHeight: 300) == 31.5)
        // Page 3 is 200 tall: top-aligned in a 150 viewport.
        #expect(layout.offset(forPage: 3, viewportHeight: 150) == 263)
        // Page 1 cannot be centred above the top.
        #expect(layout.offset(forPage: 1, viewportHeight: 300) == 0)
        #expect(layout.offset(forPage: 99, viewportHeight: 300) == 223)
    }

    /// Scrolling to a page and asking for the current page agree, except where the strip ends
    /// before the page can be centred: there the last (or first) page wins. The strip view
    /// covers that case by remembering the page it was asked to show.
    @Test func scrollingToAPageMakesItTheCurrentPage() {
        let ratios: [CGFloat?] = [0.7, 0.7, 3, 0.2, 0.7, 5, 5, 0.7, 4, 6]
        let layout = ReaderStripLayout(pageCount: ratios.count, width: 390, gap: 8, displayScale: 3) { ratios[$0 - 1] }
        for viewportHeight in [300, 844, 1_400] as [CGFloat] {
            let maximum = layout.maximumOffset(viewportHeight: viewportHeight)
            for page in 1...ratios.count {
                let offset = layout.offset(forPage: page, viewportHeight: viewportHeight)
                let expected = offset <= 0 ? 1 : (offset >= maximum ? ratios.count : page)
                #expect(
                    layout.currentPage(viewportMinY: offset, viewportHeight: viewportHeight) == expected,
                    "page \(page) viewport \(viewportHeight)"
                )
            }
        }
    }

    @Test func currentPageIsTheOneUnderTheMiddleOfTheViewport() {
        let layout = makeLayout()
        #expect(layout.currentPage(viewportMinY: 60, viewportHeight: 200) == 2)
        #expect(layout.currentPage(viewportMinY: 170, viewportHeight: 200) == 3)
        // Resting at either end reports the first or last page.
        #expect(layout.currentPage(viewportMinY: 0, viewportHeight: 300) == 1)
        #expect(layout.currentPage(viewportMinY: -40, viewportHeight: 300) == 1)
        #expect(layout.currentPage(viewportMinY: 223, viewportHeight: 300) == 4)
        #expect(layout.currentPage(viewportMinY: 260, viewportHeight: 300) == 4)
    }

    @Test func currentPageOfAStripShorterThanTheViewportIsTheMiddleOne() {
        let layout = makeLayout()
        // Everything fits: 523 points of content in a 1000 point viewport, middle at 500.
        #expect(layout.currentPage(viewportMinY: 0, viewportHeight: 1_000) == 4)
        #expect(layout.maximumOffset(viewportHeight: 1_000) == 0)
    }
}
