import EhModels
import EhNetworking
import Foundation

/// One page's preview, ready to draw: either a standalone image or a tile of a sprite sheet.
public nonisolated struct PreviewThumbnail: Identifiable, Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case image(URL)
        /// A `width` × `height` tile starting `x` pixels from the left edge of the sheet.
        case sprite(sheetURL: URL, x: Int, width: Int, height: Int)
    }

    /// 1-based page index.
    public let index: Int
    public let source: Source

    public var id: Int { index }

    /// Decodes the crop the parser encoded into a sprite-sheet URL (`CombinedPreviewURL`).
    public init(index: Int, url: URL) {
        self.index = index
        if let combined = CombinedPreviewURL.parse(url) {
            source = .sprite(
                sheetURL: combined.plainURL, x: combined.offset, width: combined.width, height: combined.height
            )
        } else {
            source = .image(url)
        }
    }

    /// Thumbnails for `urls`, ordered by page.
    public static func sorted(_ urls: [Int: URL]) -> [PreviewThumbnail] {
        urls.sorted { $0.key < $1.key }.map { PreviewThumbnail(index: $0.key, url: $0.value) }
    }
}

/// Which preview page of the gallery page holds a given page index.
///
/// `PreviewConfig.pageNumber(index:)` computes `index / batchSize`, which is off by one for an
/// index that is an exact multiple of the batch size (page 40 of a 40-per-page layout lands on
/// preview page 1 instead of 0). Indices are 1-based, so the page is `(index - 1) / batchSize`.
/// The detail feature uses this instead of the model's method.
public nonisolated enum PreviewPaging {
    /// Legacy's layout when the page did not say: normal previews, four rows.
    public static let defaultConfig = PreviewConfig.normal(rows: 4)

    /// The 0-based preview page (the site's `p`) that shows page `index` (1-based).
    public static func pageNumber(forIndex index: Int, config: PreviewConfig) -> Int {
        max(index - 1, 0) / max(config.batchSize, 1)
    }

    /// The 1-based page indices shown on preview page `pageNumber`.
    public static func indices(onPage pageNumber: Int, config: PreviewConfig) -> ClosedRange<Int> {
        let lowerBound = pageNumber * config.batchSize + 1
        return lowerBound...(lowerBound + config.batchSize - 1)
    }
}
