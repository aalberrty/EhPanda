import EhFeatures
import UIKit

/// One item of the pager: a page, or two side by side, that can be pinched and panned.
///
/// Zooming is plain `UIScrollView` zooming of a container the size of the viewport, so it runs
/// in the render server like any scroll view. Being a scroll view inside the paging scroll view
/// also gives the usual hand-over: while zoomed in, a drag pans the page, and a drag that
/// starts at the edge of the page turns it.
final class ReaderSpreadView: UIScrollView, UIScrollViewDelegate {
    private(set) var spreadIndex = -1
    private(set) var pageViews: [ReaderPageView] = []
    /// Called when a zoom gesture or animation settles: `true` if the spread is now zoomed in.
    var onZoomChange: ((Bool) -> Void)?

    private let container = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        bouncesZoom = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        scrollsToTop = false
        addSubview(container)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isZoomed: Bool { ReaderGeometry.isZoomed(zoomScale) }

    // MARK: Content

    /// Installs page views, in the order they sit on screen from left to right.
    func setPageViews(_ views: [ReaderPageView], spreadIndex: Int) {
        self.spreadIndex = spreadIndex
        pageViews = views
        views.forEach(container.addSubview)
    }

    /// Hands the page views back for recycling.
    func removePageViews() -> [ReaderPageView] {
        let views = pageViews
        pageViews = []
        spreadIndex = -1
        onZoomChange = nil
        views.forEach { $0.removeFromSuperview() }
        resetZoom()
        return views
    }

    /// Resizes to a new viewport. Zoom does not survive a size change.
    func setViewportSize(_ size: CGSize) {
        resetZoom()
        container.frame = CGRect(origin: .zero, size: size)
        contentSize = size
    }

    /// Positions the page views inside the unzoomed viewport.
    func layoutPages(aspectRatios: [CGFloat?]) {
        let frames = ReaderGeometry.spreadPageFrames(
            aspectRatios: aspectRatios, in: container.bounds.size, displayScale: traitCollection.displayScale
        )
        for (view, frame) in zip(pageViews, frames) where view.frame != frame {
            view.frame = frame
        }
    }

    // MARK: Zoom

    func resetZoom() {
        guard zoomScale != 1 || contentOffset != .zero else { return }
        setZoomScale(1, animated: false)
        contentOffset = .zero
    }

    /// Double tap: zooms in around `point` (in this view's coordinates), or back out.
    func toggleZoom(at point: CGPoint, configuration: ReaderConfiguration) {
        guard let scale = ReaderGeometry.doubleTapScale(current: zoomScale, configuration: configuration) else {
            return
        }
        let rect = ReaderGeometry.zoomRect(
            scale: scale,
            contentPoint: container.convert(point, from: self),
            viewportPoint: CGPoint(x: point.x - bounds.minX, y: point.y - bounds.minY),
            viewportSize: bounds.size
        )
        zoom(to: rect, animated: true)
        if ReaderGeometry.isZoomed(scale) {
            // Start on the sharper decode now rather than when the animation ends.
            onZoomChange?(true)
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        container
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Below 1× (while the pinch bounces) the content is smaller than the view: keep it centred.
        let size = contentSize
        container.center = CGPoint(
            x: max(size.width, bounds.width) / 2,
            y: max(size.height, bounds.height) / 2
        )
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        onZoomChange?(ReaderGeometry.isZoomed(scale))
    }
}
