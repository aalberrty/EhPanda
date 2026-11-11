import CoreGraphics
import Foundation

/// What the engine remembers about pages between the moments their views exist: aspect
/// ratios, image failures and which image sizes the host has already been told about.
/// A few numbers per page, so a thousand pages cost next to nothing.
struct ReaderPageRegistry {
    private var aspectRatios: [CGFloat?] = []
    private var failedImages: [Int: URL] = [:]
    private var reportedPixelSizes: [Int: CGSize] = [:]

    /// Ratios this close are the same shape; the difference is rounding in a downsampled decode.
    private static let aspectRatioTolerance: CGFloat = 0.005

    mutating func reset(pageCount: Int, aspectRatio: (Int) -> CGFloat?) {
        aspectRatios = (0..<max(pageCount, 0)).map { Self.usable(aspectRatio($0 + 1)) }
        failedImages = [:]
        reportedPixelSizes = [:]
    }

    func aspectRatio(forPage page: Int) -> CGFloat? {
        aspectRatios.indices.contains(page - 1) ? aspectRatios[page - 1] : nil
    }

    /// Records a page's width / height ratio. Returns whether its shape actually changed.
    mutating func setAspectRatio(_ ratio: CGFloat?, forPage page: Int) -> Bool {
        guard aspectRatios.indices.contains(page - 1), let ratio = Self.usable(ratio) else { return false }
        if let known = aspectRatios[page - 1], abs(known - ratio) <= known * Self.aspectRatioTolerance {
            return false
        }
        aspectRatios[page - 1] = ratio
        return true
    }

    func hasFailedImage(page: Int, url: URL) -> Bool {
        failedImages[page] == url
    }

    mutating func setFailedImage(_ url: URL?, forPage page: Int) {
        failedImages[page] = url
    }

    /// Whether a loaded image's size is news to the host: the first time, and when it changes.
    mutating func shouldReport(pixelSize: CGSize, forPage page: Int) -> Bool {
        guard reportedPixelSizes[page] != pixelSize else { return false }
        reportedPixelSizes[page] = pixelSize
        return true
    }

    private static func usable(_ ratio: CGFloat?) -> CGFloat? {
        guard let ratio, ratio.isFinite, ratio > 0 else { return nil }
        return ratio
    }
}
