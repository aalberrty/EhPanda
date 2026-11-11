import Kingfisher
import UIKit

/// Webtoon-style cover cropping, ported from legacy `WebtoonModifier`: a cover narrower than
/// `minAspect` (width / height) keeps only its top part, cut to `idealAspect`.
nonisolated struct WebtoonCrop: Hashable, Sendable {
    var minAspect: CGFloat = Tokens.Webtoon.minAspect
    var idealAspect: CGFloat = Tokens.Webtoon.idealAspect

    static let standard = WebtoonCrop()

    /// The region to keep in an image of `size`, or `nil` when the image is not tall enough.
    func region(in size: CGSize) -> CGRect? {
        guard size.height > 0, idealAspect > 0, size.width / size.height < minAspect else { return nil }
        return CGRect(x: 0, y: 0, width: size.width, height: min(size.height, size.width / idealAspect))
    }
}

/// Decodes an image straight to its display size, optionally applying ``WebtoonCrop`` first.
///
/// Unlike Kingfisher's `DownsamplingImageProcessor`, a decoded input is redrawn rather than
/// re-encoded to data, and the downsampling factor honours fill / fit and width-only targets.
/// Legacy applied the webtoon crop as an `ImageModifier` on every display; here the cropped,
/// downsampled bitmap is what gets cached.
nonisolated struct DownsampleProcessor: ImageProcessor {
    enum Mode: String, Sendable {
        /// The result covers the target (use with `.fill` content mode).
        case fill
        /// The result fits inside the target (use with `.fit` content mode).
        case fit
    }

    /// Target size in pixels. A zero height means "match the width, any height".
    let pixelSize: CGSize
    let mode: Mode
    let webtoon: WebtoonCrop?
    let identifier: String

    init(pixelSize: CGSize, mode: Mode = .fill, webtoon: WebtoonCrop? = nil) {
        self.pixelSize = CGSize(width: pixelSize.width.rounded(.up), height: pixelSize.height.rounded(.up))
        self.mode = mode
        self.webtoon = webtoon
        var identifier = "app.ehpanda.downsample(\(Int(self.pixelSize.width))x\(Int(self.pixelSize.height)),\(mode.rawValue)"
        if let webtoon {
            identifier += ",webtoon(\(webtoon.minAspect),\(webtoon.idealAspect))"
        }
        self.identifier = identifier + ")"
    }

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        let result: CGImage? = switch item {
        case .data(let data):
            downsample(data: data)
        case .image(let image):
            ImageDecoding.uprightCGImage(of: image).flatMap(downsample(image:))
        }
        return result.map { UIImage(cgImage: $0, scale: options.scaleFactor, orientation: .up) }
    }

    /// The factor that makes `region` cover or fit the target, capped at 1 so nothing is upscaled.
    func scale(for region: CGSize) -> CGFloat {
        guard region.width > 0, region.height > 0, pixelSize.width > 0 else { return 1 }
        let horizontal = pixelSize.width / region.width
        guard pixelSize.height > 0 else { return min(1, horizontal) }
        let vertical = pixelSize.height / region.height
        return min(1, mode == .fill ? max(horizontal, vertical) : min(horizontal, vertical))
    }

    private func downsample(data: Data) -> CGImage? {
        guard let source = ImageDecoding.source(from: data),
              let size = ImageDecoding.orientedPixelSize(of: source)
        else { return nil }
        let region = webtoon?.region(in: size)
        let factor = scale(for: region?.size ?? size)
        // ImageIO decodes straight to the reduced size, so a large original is never fully decoded.
        guard let thumbnail = ImageDecoding.thumbnail(
            from: source, maxPixelSize: max(size.width, size.height) * factor
        ) else { return nil }
        guard let region else { return thumbnail }
        let actual = CGFloat(thumbnail.width) / size.width
        return ImageDecoding.render(thumbnail, crop: region.applying(CGAffineTransform(scaleX: actual, y: actual)))
    }

    private func downsample(image: CGImage) -> CGImage? {
        let size = CGSize(width: image.width, height: image.height)
        let region = webtoon?.region(in: size) ?? CGRect(origin: .zero, size: size)
        let factor = scale(for: region.size)
        guard factor < 1 || region.size != size else { return image }
        return ImageDecoding.render(
            image, crop: region, size: CGSize(width: region.width * factor, height: region.height * factor)
        )
    }
}
