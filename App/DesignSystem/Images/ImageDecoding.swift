import CoreGraphics
import ImageIO
import UIKit

/// Decoding primitives shared by the image processors. Kingfisher calls processors on its own
/// processing queue, so everything here is `nonisolated` and touches no UI state.
nonisolated enum ImageDecoding {
    static func source(from data: Data) -> CGImageSource? {
        CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
    }

    /// Pixel size of the first frame after applying its EXIF orientation, read from the header
    /// without decoding.
    static func orientedPixelSize(of source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0
        else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        // Orientations 5...8 rotate the image by 90°.
        return (5...8).contains(orientation)
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }

    /// Decodes the first frame with its longest side at most `maxPixelSize`, never upscaling.
    static func thumbnail(from source: CGImageSource, maxPixelSize: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize.rounded(.up)),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// The full first frame, decoded lazily when it is first drawn.
    static func fullImage(from source: CGImageSource) -> CGImage? {
        CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: false] as CFDictionary)
    }

    /// Draws `crop` of `image` (top-left origin, pixels) into a new bitmap of `size` pixels.
    ///
    /// Drawing into a fresh context, instead of returning `CGImage.cropping(to:)`, yields a
    /// standalone decoded bitmap: the large source buffer is released and nothing is decoded again
    /// on the main thread at display time.
    static func render(_ image: CGImage, crop: CGRect? = nil, size: CGSize? = nil) -> CGImage? {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let region = (crop ?? bounds).integral.intersection(bounds)
        guard !region.isNull, region.width >= 1, region.height >= 1,
              let cropped = region == bounds ? image : image.cropping(to: region)
        else { return nil }

        let target = size ?? region.size
        let width = max(1, Int(target.width.rounded()))
        let height = max(1, Int(target.height.rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else { return nil }
        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// An upright `CGImage` for an already decoded image, redrawing only when it carries a
    /// non-default orientation.
    static func uprightCGImage(of image: UIImage) -> CGImage? {
        guard image.imageOrientation != .up else { return image.cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        return UIGraphicsImageRenderer(size: pixelSize, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: pixelSize)) }
            .cgImage
    }
}
