import EhFeatures
import Kingfisher
import UIKit

/// Cuts one thumbnail out of a preview sprite sheet.
///
/// The identifier contains the crop rectangle, so Kingfisher keys each thumbnail separately while
/// they share the sheet's URL. Paired with `cacheOriginalImage()` and `cacheMemoryOnly()`, the
/// sheet is downloaded once and is the only thing on disk, and each small crop sits in the
/// memory cache. Legacy instead cached a full copy of the sheet per thumbnail
/// (`KFImage.url(_:cacheKey:)`) and cropped after every load in an `ImageModifier`.
///
/// Kingfisher shares the download between the tiles of a sheet but runs each tile's processor
/// on its own, with the sheet's bytes. The sheet is therefore decoded once per URL here and the
/// tiles are cut from that bitmap; without it each of the twenty tiles decoded the whole sheet.
nonisolated struct SpriteCropProcessor: ImageProcessor {
    /// The sheets being cut up right now. A sheet's tiles are processed one after the other, so
    /// a handful is enough; each is a megabyte or a few.
    private static let sheets: RecentValueCache<URL, CGImage> = {
        let cache = RecentValueCache<URL, CGImage>(capacity: 4)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { _ in cache.removeAll() }
        return cache
    }()

    let sheetURL: URL?
    /// Crop rectangle in sheet pixels, top-left origin.
    let rect: CGRect
    let identifier: String

    /// - Parameter sheetURL: The sheet the tile is cut from; its decoded bitmap is shared under it.
    init(sheetURL: URL?, rect: CGRect) {
        let rect = rect.integral
        self.sheetURL = sheetURL
        self.rect = rect
        identifier = "app.ehpanda.sprite-crop(\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height)))"
    }

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        // A rectangle outside the sheet is a parsing error upstream; failing shows the failure view
        // instead of caching the whole sheet under a thumbnail's key.
        guard let sheet = decodedSheet(from: item), let thumbnail = ImageDecoding.render(sheet, crop: rect)
        else { return nil }
        return UIImage(cgImage: thumbnail, scale: options.scaleFactor, orientation: .up)
    }

    /// The whole sheet as a decoded bitmap, from the shared cache when another tile got there first.
    private func decodedSheet(from item: ImageProcessItem) -> CGImage? {
        let decode: () -> CGImage? = {
            let sheet: CGImage? = switch item {
            case .data(let data):
                ImageDecoding.source(from: data).flatMap(ImageDecoding.fullImage(from:))
            case .image(let image):
                ImageDecoding.uprightCGImage(of: image)
            }
            // Drawn once into a bitmap of its own: cutting a tile out of that decodes nothing.
            return sheet.flatMap { ImageDecoding.render($0) }
        }
        guard let sheetURL else { return decode() }
        return Self.sheets.value(for: sheetURL, make: decode)
    }
}
