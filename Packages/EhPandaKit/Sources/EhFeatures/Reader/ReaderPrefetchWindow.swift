import CoreGraphics

/// The pages around the visible ones that the reader keeps warm: the host resolves their URLs
/// and the engine downloads their image data.
nonisolated public enum ReaderPrefetchWindow {
    /// How many pages beyond the visible ones the window reaches on each side.
    ///
    /// Legacy prefetched `[page - 2 - limit / 2, page - 2]` and `[page + 2, page + 2 + limit / 2]`
    /// whenever a page appeared, so its reach on each side was `limit / 2 + 2`.
    public static func reach(forLimit limit: Int) -> Int {
        max(limit, 0) / 2 + 2
    }

    /// The window for the given visible pages, clamped to the gallery.
    public static func range(visible: ClosedRange<Int>, pageCount: Int, limit: Int) -> ClosedRange<Int>? {
        guard pageCount > 0 else { return nil }
        let reach = reach(forLimit: limit)
        let lower = min(max(visible.lowerBound - reach, 1), pageCount)
        let upper = min(max(visible.upperBound + reach, 1), pageCount)
        return lower...max(lower, upper)
    }

    /// The pages of `range` ordered by how soon they are likely to be needed: the visible ones
    /// first, then outwards, the page ahead before the page behind at each distance.
    public static func prioritized(_ range: ClosedRange<Int>, around visible: ClosedRange<Int>) -> [Int] {
        var pages: [Int] = []
        pages.reserveCapacity(range.count)
        pages.append(contentsOf: visible.filter(range.contains))
        var ahead = visible.upperBound + 1
        var behind = visible.lowerBound - 1
        while ahead <= range.upperBound || behind >= range.lowerBound {
            if range.contains(ahead) { pages.append(ahead) }
            if range.contains(behind) { pages.append(behind) }
            ahead += 1
            behind -= 1
        }
        return pages
    }

    /// The pages that entered and left the window, both ascending.
    public static func changes(
        from old: ClosedRange<Int>?, to new: ClosedRange<Int>?
    ) -> (added: [Int], removed: [Int]) {
        switch (old, new) {
        case (nil, nil):
            return ([], [])
        case let (nil, new?):
            return (Array(new), [])
        case let (old?, nil):
            return ([], Array(old))
        case let (old?, new?):
            return (new.filter { !old.contains($0) }, old.filter { !new.contains($0) })
        }
    }
}
