import CoreGraphics
import Testing
@testable import EhCore

@Suite struct CoverPaletteTests {
    private typealias RGB = CoverPalette.RGB

    @Test func picksTheMostCommonColourFirstThenDistinctOnes() throws {
        let sand = Pixel(243, 217, 177), orange = Pixel(224, 122, 63), teal = Pixel(47, 122, 120)
        let pixels = Array(repeating: sand, count: 60) + Array(repeating: orange, count: 30)
            + Array(repeating: teal, count: 10)

        let palette = try #require(CoverPaletteExtractor.palette(fromRGBA: rgba(pixels)))

        #expect(palette.colors.count == CoverPaletteExtractor.colorCount)
        #expect(palette.colors[0].isClose(to: sand.rgb))
        #expect(palette.colors[1].isClose(to: orange.rgb))
        #expect(palette.colors[2].isClose(to: teal.rgb))
    }

    @Test func fillsMissingColoursWithDarkerShadesOfTheAccents() throws {
        let sand = Pixel(243, 217, 177), orange = Pixel(224, 122, 63), teal = Pixel(47, 122, 120)
        let pixels = Array(repeating: sand, count: 60) + Array(repeating: orange, count: 30)
            + Array(repeating: teal, count: 10)

        let palette = try #require(CoverPaletteExtractor.palette(fromRGBA: rgba(pixels)))

        // The mockup's "darker orange and teal".
        #expect(palette.colors[3].isClose(to: orange.rgb.scaled(by: 0.72)))
        #expect(palette.colors[4].isClose(to: teal.rgb.scaled(by: 0.72)))
    }

    @Test func aFlatCoverGetsSuccessivelyDarkerShades() throws {
        let palette = try #require(
            CoverPaletteExtractor.palette(fromRGBA: rgba(Array(repeating: Pixel(200, 100, 50), count: 16)))
        )

        #expect(palette.colors.count == CoverPaletteExtractor.colorCount)
        let brightness = palette.colors.map(\.brightness)
        #expect(zip(brightness, brightness.dropFirst()).allSatisfy { $0 > $1 })
    }

    @Test func skipsNearDuplicatesWhileDistinctColoursRemain() throws {
        // Two shades of red that share no histogram bucket but are close, and a blue.
        let red = Pixel(200, 30, 30), nearRed = Pixel(216, 30, 30), blue = Pixel(30, 30, 200)
        let pixels = Array(repeating: red, count: 50) + Array(repeating: nearRed, count: 30)
            + Array(repeating: blue, count: 20)

        let palette = try #require(CoverPaletteExtractor.palette(fromRGBA: rgba(pixels)))

        #expect(palette.colors[1].isClose(to: blue.rgb))
    }

    @Test func ignoresTransparentPixels() throws {
        let opaque = Pixel(10, 200, 10)
        let pixels = Array(repeating: Pixel(255, 0, 0, alpha: 0), count: 90) + Array(repeating: opaque, count: 10)

        let palette = try #require(CoverPaletteExtractor.palette(fromRGBA: rgba(pixels)))

        #expect(palette.colors[0].isClose(to: opaque.rgb))
    }

    @Test func returnsNilWithoutOpaquePixels() {
        #expect(CoverPaletteExtractor.palette(fromRGBA: []) == nil)
        #expect(CoverPaletteExtractor.palette(fromRGBA: rgba([Pixel(1, 2, 3, alpha: 10)])) == nil)
    }

    @Test func readsAPaletteFromAnImage() throws {
        let image = try #require(Self.image(width: 100, height: 100) { context in
            context.setFillColor(red: 0.1, green: 0.2, blue: 0.8, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            context.setFillColor(red: 0.9, green: 0.9, blue: 0.1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 25))
        })

        let palette = try #require(CoverPaletteExtractor.palette(of: image))

        #expect(palette.colors[0].isClose(to: RGB(red: 0.1, green: 0.2, blue: 0.8), tolerance: 0.03))
        #expect(palette.colors[1].isClose(to: RGB(red: 0.9, green: 0.9, blue: 0.1), tolerance: 0.03))
    }

    @Test func mixesAndScalesColours() {
        let black = RGB(red: 0, green: 0, blue: 0), white = RGB(red: 1, green: 1, blue: 1)

        #expect(black.mixed(with: white, by: 0.25) == RGB(red: 0.25, green: 0.25, blue: 0.25))
        #expect(black.mixed(with: white, by: 2) == white)
        #expect(RGB(red: 0.8, green: 0.4, blue: 0.2).scaled(by: 2) == RGB(red: 1, green: 0.8, blue: 0.4))
        #expect(RGB(red: 0.2, green: 0.7, blue: 0.4).brightness == 0.7)
    }

    // MARK: - Helpers

    private struct Pixel {
        var red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8

        init(_ red: UInt8, _ green: UInt8, _ blue: UInt8, alpha: UInt8 = 255) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        var rgb: RGB {
            RGB(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
        }
    }

    private func rgba(_ pixels: [Pixel]) -> [UInt8] {
        pixels.flatMap { [$0.red, $0.green, $0.blue, $0.alpha] }
    }

    private static func image(width: Int, height: Int, draw: (CGContext) -> Void) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        draw(context)
        return context.makeImage()
    }
}

private extension CoverPalette.RGB {
    func isClose(to other: Self, tolerance: Double = 0.005) -> Bool {
        abs(red - other.red) <= tolerance && abs(green - other.green) <= tolerance
            && abs(blue - other.blue) <= tolerance
    }
}
