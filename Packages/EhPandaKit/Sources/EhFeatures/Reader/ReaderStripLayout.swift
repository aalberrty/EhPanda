import CoreGraphics

/// Geometry of the vertical reader: every page stacked top to bottom at full width, with a gap
/// in between. Pages are 1-based; all values are in the strip's own (unzoomed) coordinates.
///
/// A page whose aspect ratio is not known yet takes the legacy placeholder shape. When the
/// ratio arrives the strip is re-stacked from that page on, and `scrollAdjustment` says how far
/// to move the scroll position so that what the reader is looking at stays where it is.
nonisolated public struct ReaderStripLayout: Sendable, Equatable {
    /// Width / height of a page whose image size is unknown (legacy `Defaults.ImageSize.contentAspect`).
    public static let placeholderAspectRatio: CGFloat = 0.7

    /// A scroll position that survives width and height changes: a page and how far down it.
    nonisolated public struct Anchor: Sendable, Equatable {
        public var page: Int
        /// 0 at the top edge of the page, 1 at its bottom edge.
        public var fraction: CGFloat

        public init(page: Int, fraction: CGFloat) {
            self.page = page
            self.fraction = fraction
        }
    }

    public private(set) var width: CGFloat
    public private(set) var gap: CGFloat
    /// Heights are rounded to whole pixels of this scale so that images are not resampled.
    public let displayScale: CGFloat
    public private(set) var contentHeight: CGFloat = 0

    private var aspectRatios: [CGFloat?]
    private var heights: [CGFloat]
    private var minYs: [CGFloat]

    public init(
        pageCount: Int, width: CGFloat, gap: CGFloat, displayScale: CGFloat,
        aspectRatio: (Int) -> CGFloat?
    ) {
        let count = max(pageCount, 0)
        self.width = max(width, 0)
        self.gap = max(gap, 0)
        self.displayScale = displayScale > 0 ? displayScale : 1
        aspectRatios = (0..<count).map { aspectRatio($0 + 1) }
        heights = Array(repeating: 0, count: count)
        minYs = Array(repeating: 0, count: count)
        restack(from: 0, recomputingHeights: true)
    }

    public var pageCount: Int { heights.count }

    // MARK: Queries

    public func frame(ofPage page: Int) -> CGRect {
        guard contains(page) else { return .zero }
        return CGRect(x: 0, y: minYs[page - 1], width: width, height: heights[page - 1])
    }

    /// The page whose top edge is the last one at or above `y`, so a gap belongs to the page
    /// above it. Positions outside the strip give the first or the last page.
    public func page(atY y: CGFloat) -> Int? {
        guard !minYs.isEmpty else { return nil }
        var low = 0
        var high = minYs.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if minYs[middle] <= y {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return low + 1
    }

    /// The pages that overlap the band between `minY` and `maxY`.
    public func pages(fromY minY: CGFloat, toY maxY: CGFloat) -> ClosedRange<Int>? {
        guard var first = page(atY: minY), let last = page(atY: maxY) else { return nil }
        // `minY` may sit in the gap below `first`.
        if first < last, minYs[first - 1] + heights[first - 1] <= minY {
            first += 1
        }
        return first...max(first, last)
    }

    public func maximumOffset(viewportHeight: CGFloat) -> CGFloat {
        max(contentHeight - viewportHeight, 0)
    }

    /// Where to scroll to show `page`: centred when it fits in the viewport (as legacy does),
    /// top-aligned when it is taller. Clamped to the scrollable range.
    public func offset(forPage page: Int, viewportHeight: CGFloat) -> CGFloat {
        guard !heights.isEmpty else { return 0 }
        let frame = frame(ofPage: min(max(page, 1), pageCount))
        let proposed = frame.height <= viewportHeight ? frame.midY - viewportHeight / 2 : frame.minY
        let aligned = (proposed * displayScale).rounded() / displayScale
        return min(max(aligned, 0), maximumOffset(viewportHeight: viewportHeight))
    }

    /// The page reported as "current": the one under the middle of the viewport, as legacy
    /// does. Resting against the top or bottom of the strip reports the first or last page, so
    /// short pages at either end can still become current.
    public func currentPage(viewportMinY: CGFloat, viewportHeight: CGFloat) -> Int? {
        guard !heights.isEmpty else { return nil }
        let maximum = maximumOffset(viewportHeight: viewportHeight)
        if maximum > 0 {
            if viewportMinY <= 0 { return 1 }
            if viewportMinY >= maximum - 0.5 { return pageCount }
        }
        return page(atY: viewportMinY + viewportHeight / 2)
    }

    public func anchor(atY y: CGFloat) -> Anchor? {
        guard let page = page(atY: y) else { return nil }
        let height = heights[page - 1]
        let fraction = height > 0 ? (y - minYs[page - 1]) / height : 0
        return Anchor(page: page, fraction: min(max(fraction, 0), 1))
    }

    public func y(for anchor: Anchor) -> CGFloat {
        guard !heights.isEmpty else { return 0 }
        let frame = frame(ofPage: min(max(anchor.page, 1), pageCount))
        return frame.minY + frame.height * anchor.fraction
    }

    /// How far the scroll position has to move when a page whose top was at `pageMinY` changed
    /// height by `heightDelta`. A page that starts above the top of the viewport keeps its
    /// bottom edge still, so everything from there down stays put; a page that starts inside or
    /// below the viewport keeps its top edge and needs no adjustment.
    public static func scrollAdjustment(
        forHeightDelta heightDelta: CGFloat, pageMinY: CGFloat, viewportMinY: CGFloat
    ) -> CGFloat {
        pageMinY < viewportMinY ? heightDelta : 0
    }

    // MARK: Changes

    /// Sets a page's width / height ratio (`nil` for unknown) and returns how much its height changed.
    @discardableResult
    public mutating func setAspectRatio(_ ratio: CGFloat?, forPage page: Int) -> CGFloat {
        guard contains(page) else { return 0 }
        let index = page - 1
        aspectRatios[index] = ratio
        let newHeight = height(forAspectRatio: ratio)
        let delta = newHeight - heights[index]
        guard delta != 0 else { return 0 }
        heights[index] = newHeight
        restack(from: index, recomputingHeights: false)
        return delta
    }

    public mutating func setWidth(_ newWidth: CGFloat) {
        let newWidth = max(newWidth, 0)
        guard newWidth != width else { return }
        width = newWidth
        restack(from: 0, recomputingHeights: true)
    }

    public mutating func setGap(_ newGap: CGFloat) {
        let newGap = max(newGap, 0)
        guard newGap != gap else { return }
        gap = newGap
        restack(from: 0, recomputingHeights: false)
    }

    // MARK: Private

    private func contains(_ page: Int) -> Bool {
        page >= 1 && page <= heights.count
    }

    private func height(forAspectRatio ratio: CGFloat?) -> CGFloat {
        var usable = Self.placeholderAspectRatio
        if let ratio, ratio.isFinite, ratio > 0 {
            usable = ratio
        }
        let pixels = (width / usable * displayScale).rounded()
        return max(pixels, 1) / displayScale
    }

    private mutating func restack(from index: Int, recomputingHeights: Bool) {
        guard !heights.isEmpty else {
            contentHeight = 0
            return
        }
        var y = index > 0 ? minYs[index - 1] + heights[index - 1] + gap : 0
        for current in index..<heights.count {
            if recomputingHeights {
                heights[current] = height(forAspectRatio: aspectRatios[current])
            }
            minYs[current] = y
            y += heights[current] + gap
        }
        contentHeight = y - gap
    }
}
