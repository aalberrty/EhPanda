import CoreGraphics

/// How large an image may be decoded for the place it is shown in.
///
/// The image keeps its proportions and is never enlarged: it is reduced until it fits the
/// pixel box, the pixel budget and the texture limit, whichever is tightest. A box without a
/// height is for the continuous vertical strip, where only the width is fixed.
///
/// It lives next to the reader because that is its first user; nothing in it is reader specific.
nonisolated public struct ImageDecodeTarget: Sendable, Hashable {
    /// Bitmaps with a side longer than this cannot be drawn as a single GPU texture.
    public static let maximumPixelDimension = 16_384
    /// Default cap on decoded pixels (64 MB as 32-bit RGBA).
    public static let defaultPixelBudget = 16_000_000

    public var pixelWidth: Int
    public var pixelHeight: Int?
    public var pixelBudget: Int

    public init(pixelWidth: Int, pixelHeight: Int? = nil, pixelBudget: Int = ImageDecodeTarget.defaultPixelBudget) {
        self.pixelWidth = max(pixelWidth, 1)
        self.pixelHeight = pixelHeight.map { max($0, 1) }
        self.pixelBudget = max(pixelBudget, 1)
    }

    /// A box given in points, as a view knows it.
    public init(
        size: CGSize, constrainsHeight: Bool, displayScale: CGFloat, zoom: CGFloat = 1,
        pixelBudget: Int = ImageDecodeTarget.defaultPixelBudget
    ) {
        let factor = max(displayScale, 1) * max(zoom, 1)
        self.init(
            pixelWidth: Int((size.width * factor).rounded(.up)),
            pixelHeight: constrainsHeight ? Int((size.height * factor).rounded(.up)) : nil,
            pixelBudget: pixelBudget
        )
    }

    /// Distinguishes decodes of the same image at different targets in a cache.
    public var identifier: String {
        "fit-\(pixelWidth)x\(pixelHeight.map(String.init) ?? "any")-\(pixelBudget)"
    }

    /// The factor (at most 1) a source of the given pixel size is reduced by.
    public func scale(sourceWidth: Int, sourceHeight: Int) -> CGFloat {
        guard sourceWidth > 0, sourceHeight > 0 else { return 1 }
        let width = CGFloat(sourceWidth)
        let height = CGFloat(sourceHeight)
        var scale = min(1, CGFloat(pixelWidth) / width)
        if let pixelHeight {
            scale = min(scale, CGFloat(pixelHeight) / height)
        }
        scale = min(scale, (CGFloat(pixelBudget) / (width * height)).squareRoot())
        scale = min(scale, CGFloat(Self.maximumPixelDimension) / max(width, height))
        return scale
    }

    /// The longest side, in pixels, to decode a source of the given size at. This is the value
    /// ImageIO takes as `kCGImageSourceThumbnailMaxPixelSize`.
    public func longestSide(sourceWidth: Int, sourceHeight: Int) -> Int {
        let longest = max(sourceWidth, sourceHeight)
        guard longest > 0 else { return min(max(pixelWidth, pixelHeight ?? 0), Self.maximumPixelDimension) }
        let scaled = (CGFloat(longest) * scale(sourceWidth: sourceWidth, sourceHeight: sourceHeight)).rounded()
        return min(max(Int(scaled), 1), longest)
    }

    /// Whether an image already decoded to `width` × `height` pixels could come out larger if
    /// its source were decoded again at this target.
    ///
    /// The source size is not known here, so a source twice the decoded size is assumed; the
    /// answer is "yes" when this target would keep visibly more of it than is on screen now.
    public func allowsLargerDecode(thanWidth width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        return scale(sourceWidth: width * 2, sourceHeight: height * 2) * 2 > 1.1
    }

    /// Whether a decode at this target that produced `width` × `height` pixels was cut down by
    /// the target, which means the source has more pixels to give.
    public func limited(decodedWidth width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        // ImageIO rounds the short side, so allow a couple of pixels of slack.
        if width >= pixelWidth - 2 { return true }
        if let pixelHeight, height >= pixelHeight - 2 { return true }
        if max(width, height) >= Self.maximumPixelDimension - 2 { return true }
        return CGFloat(width) * CGFloat(height) >= CGFloat(pixelBudget) * 0.97
    }
}
