import CoreGraphics
import Testing
@testable import EhFeatures

@Suite struct ReaderGeometryTests {
    // MARK: Zoom

    @Test func doubleTapTogglesBetweenOneAndTheConfiguredScale() {
        let configuration = ReaderConfiguration(maximumZoomScale: 3, doubleTapZoomScale: 2)
        #expect(ReaderGeometry.doubleTapScale(current: 1, configuration: configuration) == 2)
        #expect(ReaderGeometry.doubleTapScale(current: 1.004, configuration: configuration) == 2)
        #expect(ReaderGeometry.doubleTapScale(current: 2, configuration: configuration) == 1)
        #expect(ReaderGeometry.doubleTapScale(current: 1.4, configuration: configuration) == 1)
    }

    @Test func doubleTapScaleIsCappedByTheMaximum() {
        let configuration = ReaderConfiguration(maximumZoomScale: 1.5, doubleTapZoomScale: 4)
        #expect(ReaderGeometry.doubleTapScale(current: 1, configuration: configuration) == 1.5)
    }

    @Test func doubleTapDoesNothingWhenThereIsNoRoomToZoom() {
        let flat = ReaderConfiguration(maximumZoomScale: 1, doubleTapZoomScale: 2)
        #expect(ReaderGeometry.doubleTapScale(current: 1, configuration: flat) == nil)
        let broken = ReaderConfiguration(maximumZoomScale: .nan, doubleTapZoomScale: .infinity)
        #expect(broken.sanitizedMaximumZoomScale == 1)
        #expect(broken.sanitizedDoubleTapZoomScale == 1)
        #expect(ReaderGeometry.doubleTapScale(current: 1, configuration: broken) == nil)
    }

    @Test func zoomRectKeepsTheTouchedPointUnderTheFinger() {
        let viewport = CGSize(width: 400, height: 800)
        let contentPoint = CGPoint(x: 300, y: 200)
        let viewportPoint = CGPoint(x: 300, y: 200)
        let rect = ReaderGeometry.zoomRect(
            scale: 2, contentPoint: contentPoint, viewportPoint: viewportPoint, viewportSize: viewport
        )
        #expect(rect == CGRect(x: 150, y: 100, width: 200, height: 400))
        // After zooming to `rect`, the content point is drawn at (point - origin) * scale.
        #expect((contentPoint.x - rect.minX) * 2 == viewportPoint.x)
        #expect((contentPoint.y - rect.minY) * 2 == viewportPoint.y)
    }

    @Test func zoomRectWorksFromAScrolledAndZoomedPosition() {
        // Zooming back out to 1× from a point deep in a strip: the visible rect is one viewport
        // tall and placed so the point keeps its distance from the top of the screen.
        let rect = ReaderGeometry.zoomRect(
            scale: 1, contentPoint: CGPoint(x: 120, y: 5_000), viewportPoint: CGPoint(x: 240, y: 300),
            viewportSize: CGSize(width: 400, height: 800)
        )
        #expect(rect == CGRect(x: -120, y: 4_700, width: 400, height: 800))
    }

    // MARK: Fitting

    @Test func aspectFitUsesTheTighterDimension() {
        let square = CGSize(width: 400, height: 400)
        #expect(ReaderGeometry.aspectFitSize(aspectRatio: 0.5, in: square) == CGSize(width: 200, height: 400))
        #expect(ReaderGeometry.aspectFitSize(aspectRatio: 2, in: square) == CGSize(width: 400, height: 200))
        #expect(ReaderGeometry.aspectFitSize(aspectRatio: 1, in: .zero) == .zero)
    }

    @Test func aSinglePageIsCentred() {
        let frames = ReaderGeometry.spreadPageFrames(
            aspectRatios: [0.5], in: CGSize(width: 400, height: 600), displayScale: 2
        )
        #expect(frames == [CGRect(x: 50, y: 0, width: 300, height: 600)])
    }

    @Test func twoPagesMeetInTheMiddle() {
        // 1000 × 400: each half is 500 × 400. A 0.5 page fits as 200 × 400, a 2.0 page as 500 × 250.
        let frames = ReaderGeometry.spreadPageFrames(
            aspectRatios: [0.5, 2], in: CGSize(width: 1_000, height: 400), displayScale: 2
        )
        #expect(frames == [
            CGRect(x: 150, y: 0, width: 200, height: 400),
            CGRect(x: 350, y: 75, width: 500, height: 250)
        ])
        #expect(frames[0].maxX == frames[1].minX)
    }

    @Test func unknownRatiosUseThePlaceholderShape() {
        let frames = ReaderGeometry.spreadPageFrames(
            aspectRatios: [nil], in: CGSize(width: 700, height: 500), displayScale: 1
        )
        #expect(frames == [CGRect(x: 175, y: 0, width: 350, height: 500)])
    }

    @Test func framesAreSnappedToPixels() {
        let frames = ReaderGeometry.spreadPageFrames(
            aspectRatios: [0.7, 0.7], in: CGSize(width: 1_001, height: 333), displayScale: 3
        )
        for frame in frames {
            for value in [frame.minX, frame.minY, frame.width, frame.height] {
                #expect(abs(value * 3 - (value * 3).rounded()) < 0.000_1)
            }
        }
        let none = ReaderGeometry.spreadPageFrames(aspectRatios: [], in: CGSize(width: 10, height: 10), displayScale: 2)
        #expect(none.isEmpty)
    }

    // MARK: Paging

    @Test func slotsRunRightToLeftWhenReadingRightToLeft() {
        #expect(ReaderGeometry.slot(forSpread: 0, spreadCount: 5, rightToLeft: false) == 0)
        #expect(ReaderGeometry.slot(forSpread: 0, spreadCount: 5, rightToLeft: true) == 4)
        #expect(ReaderGeometry.slot(forSpread: 4, spreadCount: 5, rightToLeft: true) == 0)
        for rightToLeft in [false, true] {
            for spread in 0..<5 {
                let slot = ReaderGeometry.slot(forSpread: spread, spreadCount: 5, rightToLeft: rightToLeft)
                #expect(ReaderGeometry.spread(forSlot: slot, spreadCount: 5, rightToLeft: rightToLeft) == spread)
            }
        }
    }

    @Test func nearestSlotSwitchesAtTheHalfwayPoint() {
        #expect(ReaderGeometry.nearestSlot(offsetX: 0, pageWidth: 400, slotCount: 5) == 0)
        #expect(ReaderGeometry.nearestSlot(offsetX: 199, pageWidth: 400, slotCount: 5) == 0)
        #expect(ReaderGeometry.nearestSlot(offsetX: 201, pageWidth: 400, slotCount: 5) == 1)
        #expect(ReaderGeometry.nearestSlot(offsetX: -300, pageWidth: 400, slotCount: 5) == 0)
        #expect(ReaderGeometry.nearestSlot(offsetX: 9_000, pageWidth: 400, slotCount: 5) == 4)
        #expect(ReaderGeometry.nearestSlot(offsetX: 100, pageWidth: 0, slotCount: 5) == 0)
        #expect(ReaderGeometry.nearestSlot(offsetX: .nan, pageWidth: 400, slotCount: 5) == 0)
    }

    @Test func visibleSlotsIncludeAMarginAndStayInRange() {
        // Resting on slot 2 of 6.
        #expect(ReaderGeometry.slots(fromX: 800, toX: 1_200, pageWidth: 400, slotCount: 6, margin: 0) == 2...2)
        #expect(ReaderGeometry.slots(fromX: 800, toX: 1_200, pageWidth: 400, slotCount: 6, margin: 1) == 1...3)
        // Halfway between slots 2 and 3.
        #expect(ReaderGeometry.slots(fromX: 1_000, toX: 1_400, pageWidth: 400, slotCount: 6, margin: 0) == 2...3)
        // Bouncing past either end.
        #expect(ReaderGeometry.slots(fromX: -120, toX: 280, pageWidth: 400, slotCount: 6, margin: 1) == 0...1)
        #expect(ReaderGeometry.slots(fromX: 2_100, toX: 2_500, pageWidth: 400, slotCount: 6, margin: 1) == 4...5)
        #expect(ReaderGeometry.slots(fromX: 0, toX: 400, pageWidth: 400, slotCount: 0, margin: 1) == nil)
    }
}
