import EhFeatures
import ImageIO
import Kingfisher
import UIKit

/// Turns image data into something that is ready to draw. Everything here is synchronous and
/// CPU-bound; call it off the main actor.
nonisolated enum ImageDecoder {
    /// Decodes `data`, reduced to what `target` allows.
    ///
    /// ImageIO scales while it decodes, so a large original never exists as a full bitmap, and
    /// the result is fully decoded: drawing it later costs nothing on the main thread.
    /// Animated GIFs are returned undecoded for Kingfisher's `AnimatedImageView`, which decodes
    /// a few frames at a time at the size it is shown.
    static func decode(_ data: Data, target: ImageDecodeTarget, displayScale: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        if frameCount > 1, data.kf.imageFormat == .GIF {
            return KingfisherWrapper<UIImage>.animatedImage(
                data: data, options: ImageCreatingOptions(scale: displayScale)
            )
        }

        let size = pixelSize(of: source) ?? .zero
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: target.longestSide(
                sourceWidth: Int(size.width), sourceHeight: Int(size.height)
            )
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image, scale: displayScale, orientation: .up)
    }

    /// The pixel size of an image, read from its header.
    static func pixelSize(of data: Data) -> CGSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        return CGImageSourceCreateWithData(data as CFData, options).flatMap(pixelSize(of:))
    }

    /// The pixel size of an image file, read from its header without loading the file.
    static func pixelSize(ofFileAt url: URL) -> CGSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        return CGImageSourceCreateWithURL(url as CFURL, options).flatMap(pixelSize(of:))
    }

    /// Size as displayed, that is with the EXIF orientation applied.
    private static func pixelSize(of source: CGImageSource) -> CGSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0
        else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        // Orientations 5 to 8 are rotated by a quarter turn.
        return orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }
}

nonisolated extension UIImage {
    /// The size of the bitmap, as opposed to `size`, which is in points.
    var pixelSize: CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }
}
