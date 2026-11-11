import Foundation

/// A preview that is one tile of a sprite sheet. The site serves many previews in one
/// image; the app marks the tile's size and horizontal offset on the sheet's URL with
/// private query items, so the image pipeline can crop it. These URLs are never requested
/// as is: `parse(_:)` recovers the plain sheet URL first.
public struct CombinedPreviewURL: Sendable, Equatable {
    public var plainURL: URL
    public var width: Int
    public var height: Int
    public var offset: Int

    public init(plainURL: URL, width: Int, height: Int, offset: Int) {
        self.plainURL = plainURL
        self.width = width
        self.height = height
        self.offset = offset
    }

    /// The sheet URL with `ehpandaWidth`, `ehpandaHeight` and `ehpandaOffset` appended.
    /// Takes strings because the parser reads them straight from the page's CSS.
    public static func url(plainURL: URL, width: String, height: String, offset: String) -> URL {
        RequestEncoding.appending([
            RequestEncoding.item(.ehpandaWidth, width),
            RequestEncoding.item(.ehpandaHeight, height),
            RequestEncoding.item(.ehpandaOffset, offset)
        ], to: plainURL)
    }

    /// Reads a URL made by `url(plainURL:width:height:offset:)`. Returns `nil` unless all
    /// three values are present and integers. The plain URL drops the whole query, as
    /// legacy did.
    public static func parse(_ url: URL) -> CombinedPreviewURL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return nil }
        let keys: [RequestQueryKey] = [.ehpandaWidth, .ehpandaHeight, .ehpandaOffset]
        let values = keys.compactMap { key in
            items.first { $0.name == key.rawValue }?.value.flatMap { Int($0) }
        }
        components.queryItems = nil
        guard values.count == keys.count, let plainURL = components.url else { return nil }
        return CombinedPreviewURL(plainURL: plainURL, width: values[0], height: values[1], offset: values[2])
    }
}
