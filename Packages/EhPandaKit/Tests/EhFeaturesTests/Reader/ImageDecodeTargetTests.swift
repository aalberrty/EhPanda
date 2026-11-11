import CoreGraphics
import Testing
@testable import EhFeatures

@Suite struct ImageDecodeTargetTests {
    @Test func aSourceThatAlreadyFitsIsNotScaled() {
        let target = ImageDecodeTarget(pixelWidth: 1_320, pixelHeight: 2_868)
        #expect(target.scale(sourceWidth: 1_280, sourceHeight: 1_811) == 1)
        #expect(target.longestSide(sourceWidth: 1_280, sourceHeight: 1_811) == 1_811)
    }

    @Test func aBoxLimitsWhicheverSideIsTighter() {
        let target = ImageDecodeTarget(pixelWidth: 1_000, pixelHeight: 1_000)
        #expect(target.scale(sourceWidth: 4_000, sourceHeight: 2_000) == 0.25)
        #expect(target.longestSide(sourceWidth: 4_000, sourceHeight: 2_000) == 1_000)
        #expect(target.scale(sourceWidth: 2_000, sourceHeight: 4_000) == 0.25)
        #expect(target.longestSide(sourceWidth: 2_000, sourceHeight: 4_000) == 1_000)
    }

    /// The strip only fixes the width. A long page must keep its full height, which is where
    /// "longest side fits the box" downsampling goes wrong.
    @Test func aStripTargetOnlyLimitsTheWidth() {
        let target = ImageDecodeTarget(pixelWidth: 1_200)
        #expect(target.scale(sourceWidth: 800, sourceHeight: 12_000) == 1)
        #expect(target.longestSide(sourceWidth: 800, sourceHeight: 12_000) == 12_000)
        #expect(target.scale(sourceWidth: 2_400, sourceHeight: 3_600) == 0.5)
        #expect(target.longestSide(sourceWidth: 2_400, sourceHeight: 3_600) == 1_800)
    }

    @Test func thePixelBudgetCapsLargeDecodes() {
        let target = ImageDecodeTarget(pixelWidth: 4_000, pixelBudget: 4_000_000)
        // 4000 × 16000 = 64 MP → a quarter of the side length keeps 4 MP.
        #expect(target.scale(sourceWidth: 4_000, sourceHeight: 16_000) == 0.25)
        #expect(target.longestSide(sourceWidth: 4_000, sourceHeight: 16_000) == 4_000)
    }

    @Test func theTextureLimitCapsVeryLongImages() {
        let target = ImageDecodeTarget(pixelWidth: 1_000, pixelBudget: .max)
        #expect(target.longestSide(sourceWidth: 500, sourceHeight: 40_000) == ImageDecodeTarget.maximumPixelDimension)
    }

    @Test func anUnknownSourceSizeFallsBackToTheBox() {
        #expect(ImageDecodeTarget(pixelWidth: 900, pixelHeight: 1_600).longestSide(sourceWidth: 0, sourceHeight: 0) == 1_600)
        #expect(ImageDecodeTarget(pixelWidth: 900).longestSide(sourceWidth: 0, sourceHeight: 0) == 900)
    }

    @Test func pointBoxesAreConvertedWithScaleAndZoom() {
        let fit = ImageDecodeTarget(size: CGSize(width: 393, height: 852), constrainsHeight: true, displayScale: 3)
        #expect(fit.pixelWidth == 1_179)
        #expect(fit.pixelHeight == 2_556)
        let zoomed = ImageDecodeTarget(
            size: CGSize(width: 393, height: 852), constrainsHeight: false, displayScale: 3, zoom: 2
        )
        #expect(zoomed.pixelWidth == 2_358)
        #expect(zoomed.pixelHeight == nil)
        #expect(fit.identifier != zoomed.identifier)
    }

    @Test func aDecodeThatHitTheTargetCanGrowAtALargerTarget() {
        let fit = ImageDecodeTarget(pixelWidth: 1_000, pixelHeight: 1_500)
        let zoomed = ImageDecodeTarget(pixelWidth: 3_000, pixelHeight: 4_500)
        // A 4000 × 6000 source came out as 1000 × 1500: the target cut it down.
        #expect(fit.limited(decodedWidth: 1_000, height: 1_500))
        #expect(fit.limited(decodedWidth: 999, height: 1_499))
        #expect(zoomed.allowsLargerDecode(thanWidth: 1_000, height: 1_500))
        #expect(!fit.allowsLargerDecode(thanWidth: 1_000, height: 1_500))
    }

    @Test func aDecodeSmallerThanTheTargetHasNothingMoreToGive() {
        let fit = ImageDecodeTarget(pixelWidth: 1_320, pixelHeight: 2_868)
        // The source was 1280 × 1811 and was decoded whole.
        #expect(!fit.limited(decodedWidth: 1_280, height: 1_811))
    }

    @Test func aDecodeAtTheBudgetCountsAsLimited() {
        let target = ImageDecodeTarget(pixelWidth: 5_000, pixelBudget: 4_000_000)
        #expect(target.limited(decodedWidth: 1_000, height: 4_000))
        #expect(!target.limited(decodedWidth: 1_000, height: 2_000))
        #expect(!target.limited(decodedWidth: 0, height: 0))
    }

    @Test func aLargerTargetDoesNotHelpOnceTheBudgetIsReached() {
        let zoomed = ImageDecodeTarget(pixelWidth: 9_000, pixelBudget: 4_000_000)
        #expect(!zoomed.allowsLargerDecode(thanWidth: 1_000, height: 4_000))
    }

    @Test func degenerateValuesAreClamped() {
        let target = ImageDecodeTarget(pixelWidth: 0, pixelHeight: -5, pixelBudget: 0)
        #expect(target.pixelWidth == 1)
        #expect(target.pixelHeight == 1)
        #expect(target.pixelBudget == 1)
        #expect(target.longestSide(sourceWidth: 100, sourceHeight: 100) == 1)
    }
}
