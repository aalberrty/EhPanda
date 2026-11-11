import EhModels

/// Which preview page of a gallery lists a page.
///
/// The site shows a gallery's pages on preview pages of a fixed size. The links to the viewer
/// pages and the slider's thumbnails are read from those, one preview page per request.
nonisolated public struct ReaderPreviewPaging: Sendable, Equatable {
    /// Pages listed on one preview page.
    public private(set) var batchSize: Int

    /// `config` is the layout the detail page stored. Without one the legacy default applies
    /// (`normal(rows: 4)`, 40 pages) until a response shows otherwise, see `learn`.
    public init(config: PreviewConfig?) {
        batchSize = max((config ?? .normal(rows: 4)).batchSize, 1)
    }

    /// The 0-based preview page that lists the 1-based page `index`.
    ///
    /// `PreviewConfig.pageNumber(index:)` divides the index itself, as legacy did, which is one
    /// page too far for every index that is an exact multiple of the batch size. It is not
    /// used here.
    public func previewPage(for index: Int) -> Int {
        (max(index, 1) - 1) / batchSize
    }

    /// The 1-based pages a preview page lists, not clamped to the gallery.
    public func pages(onPreviewPage number: Int) -> ClosedRange<Int> {
        let first = max(number, 0) * batchSize + 1
        return first...(first + batchSize - 1)
    }

    /// Corrects the batch size from the pages a preview page really listed. Returns whether
    /// it changed.
    ///
    /// The stored layout can be missing (the reader opened before the detail page loaded) or
    /// out of date (the account's thumbnail setting changed). A wrong size asks for the wrong
    /// preview page, and legacy then left the page without an image for good.
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
