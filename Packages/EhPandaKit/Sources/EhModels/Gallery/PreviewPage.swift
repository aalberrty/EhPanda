import Foundation

/// What one page of a gallery's preview grid (`/g/<gid>/<token>/?p=n`) lists for the gallery
/// pages it shows. The site sends both in the same HTML, so they are parsed, passed on and
/// stored together. Keys are 1-based page indices.
public struct PreviewPage: Sendable, Equatable {
    /// The thumbnails. A tile of a sprite sheet carries its crop in the URL (`CombinedPreviewURL`).
    public var previewURLs: [Int: URL]
    /// The links to the viewer pages (`/s/…`). For an account that reads through the
    /// multi-page viewer they are links into that viewer (`/mpv/…`) instead.
    public var pageURLs: [Int: URL]

    public init(previewURLs: [Int: URL] = [:], pageURLs: [Int: URL] = [:]) {
        self.previewURLs = previewURLs
        self.pageURLs = pageURLs
    }

    /// The page indices the preview page lists.
    public var indices: Set<Int> {
        Set(previewURLs.keys).union(pageURLs.keys)
    }

    public var isEmpty: Bool {
        previewURLs.isEmpty && pageURLs.isEmpty
    }
}
