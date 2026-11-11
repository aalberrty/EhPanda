import Foundation

/// How the detail page lays out previews, which determines how many fit on one page.
/// Persisted in Swift's synthesized enum form, e.g. `{"normal":{"rows":4}}`.
public enum PreviewConfig: Codable, Sendable, Hashable {
    case normal(rows: Int)
    case large(rows: Int)
}

extension PreviewConfig {
    /// Previews per page.
    public var batchSize: Int {
        switch self {
        case .normal(let rows): 10 * rows
        case .large(let rows): 5 * rows
        }
    }
}

/// Which preview page of a gallery lists a page.
///
/// The site shows a gallery's pages on preview pages of a fixed size. Thumbnails and the links
/// to the viewer pages are read from those, one preview page per request, so everything that
/// asks for one (the previews grid, the reader, the reader's slider) finds it through this.
public struct PreviewPaging: Sendable, Equatable {
    /// Legacy's layout when the detail page did not say: normal previews, four rows.
    public static let defaultConfig = PreviewConfig.normal(rows: 4)

    /// Pages listed on one preview page.
    public private(set) var batchSize: Int

    /// `config` is the layout the detail page showed. Without one the legacy default applies
    /// until a response shows otherwise, see `learn`.
    public init(config: PreviewConfig?) {
        batchSize = max((config ?? Self.defaultConfig).batchSize, 1)
    }

    /// The 0-based preview page (the site's `p`) that lists the 1-based page `index`.
    ///
    /// The legacy app divided the index itself, which put every index that is an exact
    /// multiple of the batch size (40, 80, …) on the following preview page.
    public func previewPage(for index: Int) -> Int {
        (max(index, 1) - 1) / batchSize
    }

    /// Corrects the batch size from the pages a preview page really listed. Returns whether
    /// it changed.
    ///
    /// The known layout can be missing (the gallery was opened before its detail page loaded)
    /// or out of date (the account's thumbnail setting changed). A wrong size asks for the
    /// wrong preview page, and legacy then left the page without an image for good.
    public mutating func learn(listed: some Collection<Int>, onPreviewPage number: Int, pageCount: Int) -> Bool {
        guard let lowest = listed.min(), let highest = listed.max() else { return false }
        var learned = batchSize
        if number == 0 {
            // A first preview page that ends before the gallery does is a full one.
            if lowest == 1, highest < pageCount {
                learned = highest
            }
        } else if lowest > 1, (lowest - 1) % number == 0 {
            // Preview page n starts at n × size + 1.
            learned = (lowest - 1) / number
        }
        guard learned > 0, learned != batchSize else { return false }
        batchSize = learned
        return true
    }
}
