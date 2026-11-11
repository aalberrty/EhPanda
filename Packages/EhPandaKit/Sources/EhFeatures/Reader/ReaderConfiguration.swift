import CoreGraphics
import Foundation

/// How pages are laid out and which way the reader advances.
nonisolated public enum ReaderDirection: Sendable, Hashable, CaseIterable {
    /// One continuous strip, scrolled top to bottom.
    case vertical
    /// One page (or spread) at a time; the next page is to the right.
    case leftToRight
    /// One page (or spread) at a time; the next page is to the left.
    case rightToLeft

    public var isPaged: Bool { self != .vertical }
}

/// Everything the reader engine needs to know about how to present a gallery.
/// Defaults match the legacy `Setting` defaults.
nonisolated public struct ReaderConfiguration: Sendable, Equatable {
    public var direction: ReaderDirection
    /// Shows two pages side by side in the paged directions while the view is wider than tall.
    public var allowsDualPage: Bool
    /// With dual pages, shows page 1 on its own.
    public var exceptCover: Bool
    /// Space between pages in the vertical direction, in points.
    public var pageGap: CGFloat
    /// Upper bound for pinch zooming.
    public var maximumZoomScale: CGFloat
    /// Scale a double tap zooms to; clamped to `maximumZoomScale`.
    public var doubleTapZoomScale: CGFloat
    /// Legacy "preload limit". See `ReaderPrefetchWindow` for how it maps to pages.
    public var prefetchLimit: Int
    public var isLiveTextEnabled: Bool

    public init(
        direction: ReaderDirection = .vertical,
        allowsDualPage: Bool = false,
        exceptCover: Bool = false,
        pageGap: CGFloat = 0,
        maximumZoomScale: CGFloat = 3,
        doubleTapZoomScale: CGFloat = 2,
        prefetchLimit: Int = 10,
        isLiveTextEnabled: Bool = false
    ) {
        self.direction = direction
        self.allowsDualPage = allowsDualPage
        self.exceptCover = exceptCover
        self.pageGap = pageGap
        self.maximumZoomScale = maximumZoomScale
        self.doubleTapZoomScale = doubleTapZoomScale
        self.prefetchLimit = prefetchLimit
        self.isLiveTextEnabled = isLiveTextEnabled
    }

    /// Dual pages are used only in the paged directions and only while the view is wider than tall.
    public func usesDualPage(in viewportSize: CGSize) -> Bool {
        allowsDualPage && direction.isPaged && viewportSize.width > viewportSize.height
    }

    /// Zoom limits with nonsensical values (below 1×, double tap above the maximum) removed.
    public var sanitizedMaximumZoomScale: CGFloat {
        maximumZoomScale.isFinite ? max(maximumZoomScale, 1) : 1
    }

    public var sanitizedDoubleTapZoomScale: CGFloat {
        guard doubleTapZoomScale.isFinite else { return 1 }
        return min(max(doubleTapZoomScale, 1), sanitizedMaximumZoomScale)
    }
}

/// What the host knows about one page. The image itself is the engine's business.
nonisolated public enum ReaderPageState: Sendable, Equatable {
    /// The image URL has not been resolved yet.
    case pending
    case image(URL)
    /// Resolving the image URL failed.
    case failed
}
