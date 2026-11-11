import Foundation

/// A preview that is one tile of a sprite sheet. The site serves many previews in one
/// image; the app marks the tile's size and horizontal offset on the sheet's URL with
/// private query items, so a preview stays a single URL wherever it is passed or stored and
/// the image pipeline can still crop it. These URLs are never requested as is: `parse(_:)`
/// recovers the plain sheet URL first.
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

    /// The sheet URL with `ehpandaWidth`, `ehpandaHeight` and `ehpandaOffset` appended, in
    /// that order (legacy built them from a dictionary, so its order varied between launches).
    /// Takes strings because the parser reads them straight from the page's CSS.
    public static func url(plainURL: URL, width: String, height: String, offset: String) -> URL {
        guard var components = URLComponents(url: plainURL, resolvingAgainstBaseURL: false) else { return plainURL }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: Key.width, value: width),
            URLQueryItem(name: Key.height, value: height),
            URLQueryItem(name: Key.offset, value: offset)
        ]
        return components.url ?? plainURL
    }

    /// Reads a URL made by `url(plainURL:width:height:offset:)`. Returns `nil` unless all
    /// three values are present and integers. The plain URL drops the whole query, as
    /// legacy did.
    public static func parse(_ url: URL) -> CombinedPreviewURL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return nil }
        let values = [Key.width, Key.height, Key.offset].compactMap { key in
            items.first { $0.name == key }?.value.flatMap { Int($0) }
        }
        components.queryItems = nil
        guard values.count == 3, let plainURL = components.url else { return nil }
        return CombinedPreviewURL(plainURL: plainURL, width: values[0], height: values[1], offset: values[2])
    }

    /// App-private query keys, never sent to the site.
    private enum Key {
        static let width = "ehpandaWidth"
        static let height = "ehpandaHeight"
        static let offset = "ehpandaOffset"
    }
}
