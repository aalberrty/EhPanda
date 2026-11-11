import CoreGraphics
import Testing
@testable import EhFeatures

@Suite struct ReaderTapZoneTests {
    @Test func verticalAlwaysTogglesThePanel() {
        for x in [0, 10, 200, 399, 400] as [CGFloat] {
            #expect(ReaderTapZone.action(atX: x, width: 400, direction: .vertical) == .togglePanel)
        }
    }

    @Test func leftToRightTurnsBackOnTheLeftAndForwardOnTheRight() {
        #expect(ReaderTapZone.action(atX: 79, width: 400, direction: .leftToRight) == .previousPage)
        #expect(ReaderTapZone.action(atX: 321, width: 400, direction: .leftToRight) == .nextPage)
        #expect(ReaderTapZone.action(atX: 200, width: 400, direction: .leftToRight) == .togglePanel)
    }

    @Test func rightToLeftSwapsTheEdges() {
        #expect(ReaderTapZone.action(atX: 79, width: 400, direction: .rightToLeft) == .nextPage)
        #expect(ReaderTapZone.action(atX: 321, width: 400, direction: .rightToLeft) == .previousPage)
        #expect(ReaderTapZone.action(atX: 200, width: 400, direction: .rightToLeft) == .togglePanel)
    }

    /// Legacy compared with `<` and `>`, so a tap exactly on a boundary belongs to the centre.
    @Test func boundariesBelongToTheCentre() {
        #expect(ReaderTapZone.action(atX: 80, width: 400, direction: .leftToRight) == .togglePanel)
        #expect(ReaderTapZone.action(atX: 320, width: 400, direction: .leftToRight) == .togglePanel)
    }

    @Test func aViewWithoutWidthTogglesThePanel() {
        #expect(ReaderTapZone.action(atX: 0, width: 0, direction: .leftToRight) == .togglePanel)
    }
}
