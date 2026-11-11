import EhFeatures
import Kingfisher
import UIKit

/// What a page view is asked to show. The engine derives it from the host's page state and
/// from the image failures it remembers.
enum ReaderPageContent: Equatable {
    /// The image URL is not resolved yet.
    case pending
    /// Resolving the image URL failed.
    case resolutionFailed
    case image(URL)
    /// The image at the URL could not be loaded.
    case imageFailed
}

protocol ReaderPageViewDelegate: AnyObject {
    func pageView(_ pageView: ReaderPageView, didLoadImageWithPixelSize pixelSize: CGSize)
    func pageViewDidFailToLoadImage(_ pageView: ReaderPageView)
    func pageViewDidRequestRetry(_ pageView: ReaderPageView)
    func contextMenu(for pageView: ReaderPageView) -> UIMenu?
}

/// One page: its image, or a placeholder that says what the page is waiting for.
///
/// It is the reader's "cell": both reading modes recycle these, and everything that changes
/// for a page (URL resolved, image loaded, failure, zoom level) ends up as a call on the one
/// view of that page. Delegate callbacks are never made from inside `configure` or
/// `setDecodeRequest`, so the scroll views can call those while they are laying out.
final class ReaderPageView: UIView, UIContextMenuInteractionDelegate {
    private struct Load: Equatable {
        /// Tells apart two loads of the same image, so that a cancelled one finishing late
        /// cannot be mistaken for its replacement.
        var id: Int
        var url: URL
        var request: ReaderDecodeRequest
    }

    weak var delegate: ReaderPageViewDelegate?
    private(set) var page = 0

    private let imageView = AnimatedImageView()
    private let statusView = ReaderPageStatusView()
    private var content: ReaderPageContent = .pending
    private var request: ReaderDecodeRequest?
    /// The load whose image is on screen.
    private var shown: Load?
    /// The load in flight, which may be an upgrade of `shown`.
    private var loading: Load?
    private var loadTask: Task<Void, Never>?
    private var lastLoadID = 0
    private var liveText: ReaderLiveText?
    private var isLiveTextEnabled = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true

        statusView.frame = bounds
        statusView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        statusView.onRetry = { [weak self] in
            guard let self else { return }
            delegate?.pageViewDidRequestRetry(self)
        }
        addSubview(statusView)

        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        addSubview(imageView)

        addInteraction(UIContextMenuInteraction(delegate: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        loadTask?.cancel()
    }

    // MARK: Configuration

    /// Shows `content` for `page`. Calling it again for the same page only changes what differs.
    func configure(page: Int, content: ReaderPageContent, request: ReaderDecodeRequest, isLiveTextEnabled: Bool) {
        if page != self.page {
            prepareForReuse()
            self.page = page
            statusView.setPageNumber(page)
        }
        self.request = request
        self.content = content
        setLiveTextEnabled(isLiveTextEnabled)

        switch content {
        case .pending:
            showStatus(.resolving)
        case .resolutionFailed, .imageFailed:
            showStatus(.failed)
        case .image(let url):
            show(url, request: request)
        }
    }

    /// The page's content changed (URL resolved, failure, retry); everything else stays.
    func setContent(_ newContent: ReaderPageContent) {
        guard page > 0, let request else { return }
        configure(page: page, content: newContent, request: request, isLiveTextEnabled: isLiveTextEnabled)
    }

    /// The size the image is needed at changed (zoom, rotation). Loads a larger decode if the
    /// source has more to give and keeps the current image on screen meanwhile.
    func setDecodeRequest(_ newRequest: ReaderDecodeRequest) {
        guard newRequest != request else { return }
        request = newRequest
        guard case .image(let url) = content else { return }
        if let shown, shown.url == url {
            upgradeIfUseful(from: shown, to: newRequest)
        } else if loading?.url == url {
            startLoad(makeLoad(url, newRequest))
        }
    }

    func setLiveTextEnabled(_ isEnabled: Bool) {
        let isEnabled = isEnabled && ReaderLiveText.isSupported
        guard isEnabled != isLiveTextEnabled else { return }
        isLiveTextEnabled = isEnabled
        if isEnabled {
            analyzeShownImage()
        } else {
            liveText?.detach()
            liveText = nil
        }
    }

    /// Drops everything page specific. The view can then wait in a pool without holding a bitmap.
    func prepareForReuse() {
        cancelLoad()
        clearImage()
        statusView.pause()
        page = 0
        content = .pending
        request = nil
    }

    /// Whether Live Text should get a touch at `point` (in this view's coordinates) rather than
    /// the reader's own tap handling.
    func liveTextWantsTouch(at point: CGPoint) -> Bool {
        liveText?.wantsTouch(at: convert(point, to: imageView)) ?? false
    }

    // MARK: Loading

    private func show(_ url: URL, request: ReaderDecodeRequest) {
        if let shown, shown.url == url {
            showImage()
            upgradeIfUseful(from: shown, to: request)
            return
        }
        if let loading, loading.url == url {
            if loading.request != request {
                startLoad(makeLoad(url, request))
            }
            return
        }
        clearImage()
        let load = makeLoad(url, request)
        if let image = ImagePipeline.cachedImage(for: url, target: request.target) {
            cancelLoad()
            display(image, for: load, animated: false)
            // Not from inside `configure`: the report can change the layout around this view.
            Task { [weak self] in self?.reportLoaded(load) }
        } else {
            showStatus(.loading)
            startLoad(load)
        }
    }

    private func upgradeIfUseful(from shown: Load, to request: ReaderDecodeRequest) {
        guard shown.request.target != request.target, loading?.request.target != request.target,
              let image = imageView.image, image.kf.frameSource == nil
        else { return }
        let size = image.pixelSize
        let width = Int(size.width)
        let height = Int(size.height)
        // Worth it only if the decode on screen was cut down and the new target cuts less.
        guard shown.request.target.limited(decodedWidth: width, height: height),
              request.target.allowsLargerDecode(thanWidth: width, height: height)
        else { return }
        startLoad(makeLoad(shown.url, request))
    }

    private func makeLoad(_ url: URL, _ request: ReaderDecodeRequest) -> Load {
        lastLoadID += 1
        return Load(id: lastLoadID, url: url, request: request)
    }

    private func startLoad(_ load: Load) {
        loadTask?.cancel()
        loading = load
        let scale = traitCollection.displayScale
        loadTask = Task { [weak self] in
            do {
                let image = try await ImagePipeline.image(
                    for: load.url, target: load.request.target, displayScale: scale,
                    keepsInMemory: load.request.keepsInMemory,
                    progress: { [weak self] fraction in self?.updateProgress(fraction, for: load) }
                )
                guard !Task.isCancelled else { return }
                self?.finish(load, with: image)
            } catch {
                guard !Task.isCancelled else { return }
                self?.fail(load)
            }
        }
    }

    private func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
        loading = nil
    }

    private func updateProgress(_ fraction: Double, for load: Load) {
        guard loading == load, shown == nil else { return }
        statusView.setProgress(Float(fraction))
    }

    private func finish(_ load: Load, with image: UIImage) {
        // A load that was replaced or cancelled finishes without touching the view.
        guard loading == load else { return }
        loading = nil
        loadTask = nil
        display(image, for: load, animated: shown == nil)
        reportLoaded(load)
    }

    private func fail(_ load: Load) {
        guard loading == load else { return }
        loading = nil
        loadTask = nil
        // A failed upgrade leaves the image that is already there.
        guard shown == nil else { return }
        content = .imageFailed
        showStatus(.failed)
        delegate?.pageViewDidFailToLoadImage(self)
    }

    private func reportLoaded(_ load: Load) {
        guard shown == load, let image = imageView.image else { return }
        delegate?.pageView(self, didLoadImageWithPixelSize: image.pixelSize)
    }

    // MARK: Display

    private func display(_ image: UIImage, for load: Load, animated: Bool) {
        // A sharper decode of the picture that is already there keeps its text analysis.
        let isUpgrade = shown?.url == load.url
        shown = load
        imageView.image = image
        showImage()
        if animated {
            // The image fades in over the placeholder (legacy faded for 0.25 s).
            statusView.isHidden = false
            imageView.alpha = 0
            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.imageView.alpha = 1
            } completion: { [weak self] _ in
                guard let self, shown != nil else { return }
                statusView.isHidden = true
            }
        }
        if !isUpgrade {
            analyzeShownImage()
        }
    }

    private func showImage() {
        imageView.isHidden = false
        statusView.isHidden = true
        statusView.pause()
    }

    private func showStatus(_ mode: ReaderPageStatusView.Mode) {
        if mode != .loading {
            cancelLoad()
        }
        clearImage()
        statusView.isHidden = false
        statusView.setMode(mode)
    }

    private func clearImage() {
        guard shown != nil || !imageView.isHidden else { return }
        shown = nil
        imageView.layer.removeAllAnimations()
        imageView.alpha = 1
        imageView.image = nil
        imageView.isHidden = true
        liveText?.clear()
    }

    private func analyzeShownImage() {
        // Animated images change under the analysis, so they are left alone.
        guard isLiveTextEnabled, shown != nil, let image = imageView.image, image.kf.frameSource == nil else {
            return
        }
        if liveText == nil {
            liveText = ReaderLiveText(imageView: imageView)
        }
        liveText?.analyze(image)
    }

    // MARK: Context menu

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        // A long press on recognised text selects it instead.
        guard page > 0, !liveTextWantsTouch(at: location), let menu = delegate?.contextMenu(for: self) else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in menu }
    }
}
