import CoreGraphics

/// Zoom, fitting and paging arithmetic shared by the reader's scroll views.
nonisolated public enum ReaderGeometry {
    // MARK: Zoom

    /// Zoom scales closer than this to 1× count as "not zoomed".
    public static let zoomTolerance: CGFloat = 0.01

    public static func isZoomed(_ scale: CGFloat) -> Bool {
        scale > 1 + zoomTolerance
    }

    /// The scale a double tap should animate to, or `nil` when it would change nothing.
    /// A zoomed view goes back to 1×, an unzoomed one to the double-tap scale.
    public static func doubleTapScale(current: CGFloat, configuration: ReaderConfiguration) -> CGFloat? {
        if isZoomed(current) { return 1 }
        let target = configuration.sanitizedDoubleTapZoomScale
        return isZoomed(target) ? target : nil
    }

    /// The rectangle, in the zoomed view's own coordinates, to hand to `UIScrollView.zoom(to:)`
    /// so that the content under the finger stays under the finger at the new scale.
    ///
    /// - Parameters:
    ///   - contentPoint: The touched point in the zoomed view's coordinates.
    ///   - viewportPoint: The same point relative to the visible top-left corner of the scroll view.
    public static func zoomRect(
        scale: CGFloat, contentPoint: CGPoint, viewportPoint: CGPoint, viewportSize: CGSize
    ) -> CGRect {
        guard scale > 0 else { return CGRect(origin: .zero, size: viewportSize) }
        return CGRect(
            x: contentPoint.x - viewportPoint.x / scale,
            y: contentPoint.y - viewportPoint.y / scale,
            width: viewportSize.width / scale,
            height: viewportSize.height / scale
        )
    }

    // MARK: Fitting

    /// A width / height ratio that can be laid out, falling back to the placeholder shape.
    public static func usableAspectRatio(_ ratio: CGFloat?) -> CGFloat {
        guard let ratio, ratio.isFinite, ratio > 0 else { return ReaderStripLayout.placeholderAspectRatio }
        return ratio
    }

    /// The largest size with the given width / height ratio that fits in `bounds`.
    public static func aspectFitSize(aspectRatio: CGFloat, in bounds: CGSize) -> CGSize {
        guard bounds.width > 0, bounds.height > 0, aspectRatio > 0 else { return .zero }
        if bounds.width / bounds.height > aspectRatio {
            return CGSize(width: bounds.height * aspectRatio, height: bounds.height)
        }
        return CGSize(width: bounds.width, height: bounds.width / aspectRatio)
    }

    /// Snaps a rectangle's edges to whole pixels.
    public static func pixelAligned(_ rect: CGRect, displayScale: CGFloat) -> CGRect {
        let scale = displayScale > 0 ? displayScale : 1
        let minX = (rect.minX * scale).rounded() / scale
        let minY = (rect.minY * scale).rounded() / scale
        let maxX = (rect.maxX * scale).rounded() / scale
        let maxY = (rect.maxY * scale).rounded() / scale
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Frames of the pages of one spread inside a viewport, in on-screen order.
    ///
    /// A single page is fitted and centred. Two pages are each fitted into their half and then
    /// pushed together so that they meet in the middle like an open book, which is what the
    /// legacy `HStack` of two `scaledToFit` images produced.
    public static func spreadPageFrames(
        aspectRatios: [CGFloat?], in viewport: CGSize, displayScale: CGFloat
    ) -> [CGRect] {
        guard !aspectRatios.isEmpty, viewport.width > 0, viewport.height > 0 else { return [] }
        let slot = CGSize(width: viewport.width / CGFloat(aspectRatios.count), height: viewport.height)
        let sizes = aspectRatios.map { aspectFitSize(aspectRatio: usableAspectRatio($0), in: slot) }
        var x = (viewport.width - sizes.reduce(0) { $0 + $1.width }) / 2
        return sizes.map { size in
            let frame = CGRect(x: x, y: (viewport.height - size.height) / 2, width: size.width, height: size.height)
            x += size.width
            return pixelAligned(frame, displayScale: displayScale)
        }
    }

    // MARK: Paging

    /// Position of a spread in the horizontal scroll view, counted from the left edge.
    /// Right-to-left reading puts the first spread at the far right.
    public static func slot(forSpread index: Int, spreadCount: Int, rightToLeft: Bool) -> Int {
        rightToLeft ? spreadCount - 1 - index : index
    }

    /// Inverse of `slot(forSpread:spreadCount:rightToLeft:)`; the mapping is its own inverse.
    public static func spread(forSlot slot: Int, spreadCount: Int, rightToLeft: Bool) -> Int {
        rightToLeft ? spreadCount - 1 - slot : slot
    }

    /// The slot nearest to a horizontal scroll offset, clamped to the valid range.
    public static func nearestSlot(offsetX: CGFloat, pageWidth: CGFloat, slotCount: Int) -> Int {
        guard pageWidth > 0, slotCount > 0, offsetX.isFinite else { return 0 }
        return min(max(Int((offsetX / pageWidth).rounded()), 0), slotCount - 1)
    }

    /// The slots that overlap the horizontal band `minX..<maxX`, widened by `margin` slots on
    /// each side and clamped to the valid range.
    public static func slots(
        fromX minX: CGFloat, toX maxX: CGFloat, pageWidth: CGFloat, slotCount: Int, margin: Int
    ) -> ClosedRange<Int>? {
        guard pageWidth > 0, slotCount > 0, minX.isFinite, maxX.isFinite else { return nil }
        let first = Int((minX / pageWidth).rounded(.down)) - margin
        // The right edge is exclusive: a viewport resting exactly on a slot shows only that slot.
        let last = Int((maxX / pageWidth).rounded(.up)) - 1 + margin
        let lower = min(max(first, 0), slotCount - 1)
        let upper = min(max(last, 0), slotCount - 1)
        return lower...max(lower, upper)
    }
}
