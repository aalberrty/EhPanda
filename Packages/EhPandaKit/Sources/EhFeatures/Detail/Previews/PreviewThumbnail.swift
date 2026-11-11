import EhModels
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
