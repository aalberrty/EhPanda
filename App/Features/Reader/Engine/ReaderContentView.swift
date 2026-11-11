import EhFeatures
import UIKit

/// How a page view should decode its image.
struct ReaderDecodeRequest: Equatable {
    var target: ImageDecodeTarget
    /// Zoomed-in decodes are large and short-lived, so they stay out of the memory cache.
    var keepsInMemory: Bool
}

/// What the scroll view of a reading mode needs from the engine.
protocol ReaderContentHost: AnyObject {
    /// Width / height of a page's image, if the host or an earlier load has told us.
    func aspectRatio(forPage page: Int) -> CGFloat?

    /// Fills a recycled or new page view with the page's current content.
    func configure(_ pageView: ReaderPageView, forPage page: Int, request: ReaderDecodeRequest)

    func contentDidChangeCurrentPage(_ page: Int)

    /// The pages on screen, or the pages that have a view, changed.
    func contentDidChangeVisiblePages()
}

/// One reading mode: the vertical strip or the horizontal pager. The engine owns exactly one
/// at a time and replaces it when the reader switches between the two.
protocol ReaderContentView: UIScrollView {
    var host: ReaderContentHost? { get set }

    /// The page to report as current.
    var currentPage: Int { get }

    /// Pages that are at least partly on screen.
    var visiblePages: ClosedRange<Int>? { get }

    /// Pages that have a view, which includes a margin around the visible ones. These load
    /// their images themselves, so the prefetcher leaves them alone.
    var loadedPages: ClosedRange<Int>? { get }

    /// Zoom limits, gap and the like. Direction and page layout changes go through the engine.
    func apply(_ configuration: ReaderConfiguration)

    func scroll(toPage page: Int, animated: Bool)

    /// Moves by whole pages (or spreads). Returns `false` at either end of the gallery.
    func advance(by offset: Int, animated: Bool) -> Bool

    func pageView(forPage page: Int) -> ReaderPageView?

    func forEachPageView(_ body: (ReaderPageView) -> Void)

    /// The engine learned (or changed) a page's aspect ratio.
    func aspectRatioDidChange(forPage page: Int)

    /// Double tap at `point`, in this view's coordinates.
    func toggleZoom(at point: CGPoint)
}

extension UIColor {
    /// Behind and between pages, and the fill of a page that has no image yet (as in legacy).
    static let readerBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemGray6 : .systemGray4
    }
}
