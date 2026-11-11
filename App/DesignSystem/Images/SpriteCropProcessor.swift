import Kingfisher
import UIKit

/// Cuts one thumbnail out of a preview sprite sheet.
///
/// The identifier contains the crop rectangle, so Kingfisher keys each thumbnail separately while
/// they share the sheet's URL. Paired with `cacheOriginalImage()`, the sheet is downloaded once
/// and kept on disk only, and each small crop is what sits in the memory cache. Legacy instead
/// cached a full copy of the sheet per thumbnail (`KFImage.url(_:cacheKey:)`) and cropped after
/// every load in an `ImageModifier`.
nonisolated struct SpriteCropProcessor: ImageProcessor {
    /// Crop rectangle in sheet pixels, top-left origin.
    let rect: CGRect
    let identifier: String

    init(rect: CGRect) {
        let rect = rect.integral
        self.rect = rect
        identifier = "app.ehpanda.sprite-crop(\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height)))"
    }

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        let sheet: CGImage? = switch item {
        case .data(let data):
            ImageDecoding.source(from: data).flatMap(ImageDecoding.fullImage(from:))
        case .image(let image):
            ImageDecoding.uprightCGImage(of: image)
        }
        // A rectangle outside the sheet is a parsing error upstream; failing shows the failure view
        // instead of caching the whole sheet under a thumbnail's key.
        guard let sheet, let thumbnail = ImageDecoding.render(sheet, crop: rect) else { return nil }
        return UIImage(cgImage: thumbnail, scale: options.scaleFactor, orientation: .up)
    }
}
