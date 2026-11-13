import CoreGraphics

/// The main colours of a gallery cover, for the cover glow and Home's cards.
///
/// `colors[0]` is the cover's most common colour; the rest differ from it and from each other,
/// most common first. A cover with fewer distinct colours is filled up with darker shades of
/// the ones it has, so there are always ``CoverPaletteExtractor/colorCount`` colours.
public struct CoverPalette: Hashable, Sendable {
    /// An sRGB colour, each component in 0...1.
    public struct RGB: Hashable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// This colour moved toward `other` by `amount` (0 keeps it, 1 gives `other`).
        public func mixed(with other: RGB, by amount: Double) -> RGB {
            let amount = min(max(amount, 0), 1)
            return RGB(
                red: red + (other.red - red) * amount,
                green: green + (other.green - green) * amount,
                blue: blue + (other.blue - blue) * amount
            )
        }

        /// Each component scaled by `factor`; below 1 darkens.
        public func scaled(by factor: Double) -> RGB {
            RGB(red: clamp(red * factor), green: clamp(green * factor), blue: clamp(blue * factor))
        }

        /// The HSB brightness: the largest component.
        public var brightness: Double {
            max(red, green, blue)
        }

        private func clamp(_ value: Double) -> Double {
            min(max(value, 0), 1)
        }
    }

    public let colors: [RGB]

    public init(colors: [RGB]) {
        self.colors = colors
    }
}

/// Finds a cover's palette in a small thumbnail of it. Pure CPU work: call it off the main actor.
public enum CoverPaletteExtractor {
    /// How many colours a palette has.
    public static let colorCount = 5
    /// The thumbnail the app decodes for extraction: enough pixels to find the main colours.
    public static let samplePixelSize = CGSize(width: 24, height: 33)

    /// The palette of `image`, drawn at no more than twice ``samplePixelSize``.
    public static func palette(of image: CGImage) -> CoverPalette? {
        rgbaPixels(of: image).flatMap(palette(fromRGBA:))
    }

    /// The palette of 8-bit RGBA pixels. Colours are counted in a coarse 4-bit histogram; the
    /// most common bucket comes first, then the next most common buckets that are far enough
    /// from those already picked. Mostly transparent pixels are skipped. `nil` when no pixel is
    /// opaque enough.
    public static func palette(fromRGBA pixels: [UInt8]) -> CoverPalette? {
        let ranked = rankedColors(fromRGBA: pixels)
        guard let dominant = ranked.first else { return nil }

        var picked = [dominant]
        // Unit-cube distances: 0.3 separates clearly different hues, 0.15 still a visible shade.
        for threshold in [0.3, 0.15] where picked.count < colorCount {
            for color in ranked where picked.count < colorCount {
                if picked.allSatisfy({ distance($0, color) > threshold }) {
                    picked.append(color)
                }
            }
        }
        // Too few distinct colours: add darker shades, accents first, so the glow keeps depth.
        var sources = picked.count > 1 ? Array(picked.dropFirst()) : picked
        var next = 0
        while picked.count < colorCount {
            let shade = sources[next] * 0.72
            picked.append(shade)
            // Once every source has a shade, the next round darkens the shades.
            sources[next] = shade
            next = (next + 1) % sources.count
        }
        return CoverPalette(colors: picked.map { CoverPalette.RGB(red: $0.x, green: $0.y, blue: $0.z) })
    }

    /// The mean colour of each occupied histogram bucket, most common first. Ties keep bucket
    /// order, so the result does not depend on hashing.
    private static func rankedColors(fromRGBA pixels: [UInt8]) -> [SIMD3<Double>] {
        var counts = [Int](repeating: 0, count: 4096)
        var sums = [SIMD3<Double>](repeating: .zero, count: 4096)
        for offset in stride(from: 0, to: pixels.count - 3, by: 4) where pixels[offset + 3] > 127 {
            let red = Int(pixels[offset]), green = Int(pixels[offset + 1]), blue = Int(pixels[offset + 2])
            let bucket = (red >> 4) << 8 | (green >> 4) << 4 | blue >> 4
            counts[bucket] += 1
            sums[bucket] += SIMD3(Double(red), Double(green), Double(blue)) / 255
        }
        return counts.indices
            .filter { counts[$0] > 0 }
            .sorted { counts[$0] != counts[$1] ? counts[$0] > counts[$1] : $0 < $1 }
            .map { sums[$0] / Double(counts[$0]) }
    }

    private static func distance(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        let delta = lhs - rhs
        return (delta * delta).sum().squareRoot()
    }

    /// `image` redrawn as 8-bit sRGB RGBA, no larger than twice the sample size.
    static func rgbaPixels(of image: CGImage) -> [UInt8]? {
        let width = min(image.width, Int(samplePixelSize.width) * 2)
        let height = min(image.height, Int(samplePixelSize.height) * 2)
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
