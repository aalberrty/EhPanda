import CoreGraphics
import EhModels
import Kingfisher
import Observation
import SwiftUI

/// Four colours taken from a card's cover, standing in for legacy UIImageColors' background,
/// primary, secondary and detail colours.
nonisolated struct CardPalette: Hashable, Sendable {
    struct RGB: Hashable, Sendable {
        var red: Double
        var green: Double
        var blue: Double
    }

    /// The most common colour, then three others that differ from it and from each other.
    let colors: [RGB]
}

/// Palettes of the cards on screen, keyed by gallery id.
///
/// A palette is extracted once per gallery and kept for the screen's lifetime: the same gallery
/// keeps the same cover, so a reload that returns it again reuses its colours.
@Observable
final class CardPaletteStore {
    private(set) var palettes: [String: CardPalette] = [:]
    @ObservationIgnored private var pending: Set<String> = []

    /// Extracts the palette of `gallery`'s cover unless it is known or already being extracted.
    /// Called from a card's `.task`, so scrolling the card away cancels it.
    func loadPalette(for gallery: Gallery) async {
        guard let url = gallery.coverURL, palettes[gallery.id] == nil,
              pending.insert(gallery.id).inserted
        else { return }
        defer { pending.remove(gallery.id) }
        guard let palette = await CardPaletteExtractor.palette(for: url) else { return }
        palettes[gallery.id] = palette
    }
}

/// Builds a palette from a thumbnail of the cover, entirely off the main actor.
nonisolated enum CardPaletteExtractor {
    /// Side of the sampled thumbnail in pixels: enough to find the dominant colours.
    private static let sampleSize = CGSize(width: 24, height: 33)

    static func palette(for url: URL) async -> CardPalette? {
        // Kingfisher reuses the original the cover view downloaded (or joins its download) and
        // decodes it straight to the thumbnail on its own queue; only the thumbnail is cached.
        let options: KingfisherOptionsInfo = [
            .processor(DownsampleProcessor(pixelSize: sampleSize, mode: .fill)),
            .cacheOriginalImage,
            .cacheMemoryOnly,
            .scaleFactor(1)
        ]
        guard let result = try? await KingfisherManager.shared.retrieveImage(with: url, options: options),
              !Task.isCancelled,
              let image = result.image.cgImage
        else { return nil }
        return await analyze(image)
    }

    @concurrent
    static func analyze(_ image: CGImage) async -> CardPalette? {
        guard let pixels = rgbaPixels(of: image) else { return nil }
        return palette(fromRGBA: pixels)
    }

    /// Picks the four colours from 8-bit RGBA pixels: colours are counted in a coarse 4-bit
    /// histogram, the most common bucket is the background, and the next most common buckets
    /// far enough from those already picked fill the rest.
    static func palette(fromRGBA pixels: [UInt8]) -> CardPalette? {
        var counts = [Int](repeating: 0, count: 4096)
        var sums = [SIMD3<Double>](repeating: .zero, count: 4096)
        for offset in stride(from: 0, to: pixels.count - 3, by: 4) where pixels[offset + 3] > 127 {
            let red = Int(pixels[offset]), green = Int(pixels[offset + 1]), blue = Int(pixels[offset + 2])
            let bucket = (red >> 4) << 8 | (green >> 4) << 4 | blue >> 4
            counts[bucket] += 1
            sums[bucket] += SIMD3(Double(red), Double(green), Double(blue)) / 255
        }
        let ranked = counts.indices
            .filter { counts[$0] > 0 }
            .sorted { counts[$0] > counts[$1] }
            .map { sums[$0] / Double(counts[$0]) }
        guard let background = ranked.first else { return nil }

        var picked = [background]
        for threshold in [0.3, 0.15, 0.0] where picked.count < 4 {
            for color in ranked where picked.count < 4 {
                if picked.allSatisfy({ distance($0, color) > threshold }) {
                    picked.append(color)
                }
            }
        }
        // A flat cover: vary the brightness of what there is.
        while picked.count < 4 {
            picked.append(picked[picked.count - 1] * 0.75)
        }
        return CardPalette(colors: picked.map { CardPalette.RGB(red: $0.x, green: $0.y, blue: $0.z) })
    }

    private static func distance(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        let delta = lhs - rhs
        return (delta * delta).sum().squareRoot()
    }

    private static func rgbaPixels(of image: CGImage) -> [UInt8]? {
        let width = min(image.width, Int(sampleSize.width) * 2)
        let height = min(image.height, Int(sampleSize.height) * 2)
        guard width > 0, height > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? pixels : nil
    }
}

extension CardPalette.RGB {
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}
