import EhDatabase
import EhModels
import Foundation

// The control panel: slider and preview strip, auto-play, and the "reload" commands.
extension ReaderModel {
    /// How long the slider has to rest before thumbnails are fetched for where it is.
    static let previewDelay: Duration = .milliseconds(150)

    // MARK: Slider

    /// The slider was grabbed or let go. While it is held the preview strip is up and the
    /// reader stays where it is; letting go jumps to the chosen page.
    public func sliderEditingChanged(_ isEditing: Bool) {
        guard isEditing != showsSliderPreview else { return }
        showsSliderPreview = isEditing
        // Legacy: showing or hiding the strip turns auto-play off.
        setAutoPlay(.off)
        previewDebounce?.cancel()
        previewDebounce = nil
        if isEditing {
            loadStripPreviews()
        } else {
            jump(to: sliderPage)
        }
    }

    /// The slider moved. Without the strip (an accessibility adjustment, for example) the
    /// reader follows at once.
    public func setSliderPage(_ page: Int) {
        let page = min(max(page, 1), max(pageCount, 1))
        guard page != sliderPage else { return }
        sliderPage = page
        if showsSliderPreview {
            scheduleStripPreviews()
        } else {
            jump(to: page)
        }
    }

    /// The pages of the preview strip, centred on the slider. Pages outside the gallery are
    /// included; the strip keeps their place empty.
    public var previewStripPages: [Int] {
        let reach = max(previewStripLength - 1, 0) / 2
        return Array((sliderPage - reach)...(sliderPage + reach))
    }

    private func jump(to page: Int) {
        guard page != currentPage else { return }
        engine?.scrollToPage(page)
    }

    /// A drag across the slider passes every preview page of the gallery; only where it
    /// rests are thumbnails fetched.
    private func scheduleStripPreviews() {
        previewDebounce?.cancel()
        previewDebounce = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: Self.previewDelay)
            } catch {
                return
            }
            self?.loadStripPreviews()
        }
    }

    private func loadStripPreviews() {
        for page in previewStripPages where page >= 1 && page <= pageCount && previewURLs[page] == nil {
            previews.load(previewPage: resolver.paging.previewPage(for: page))
        }
    }

    /// A preview page was fetched, for the pages being read or for the strip. Whoever asked,
    /// both halves are kept: the viewer links go to the resolver, the thumbnails to the strip,
    /// and both to the database, so neither is fetched again in this session or the next.
    func previewPageDidLoad(_ listed: PreviewPage, previewPage: Int) {
        resolver.adopt(listed, previewPage: previewPage)
        if !listed.previewURLs.isEmpty {
            previewURLs.merge(listed.previewURLs) { _, new in new }
        }
        for page in GalleryPage.pages(gid: gallery.gid, listedOn: listed) {
            writer.add(page)
        }
        if showsSliderPreview {
            // The strip may reach onto a preview page that turned out to be another one.
            loadStripPreviews()
        }
    }

    // MARK: Auto-play

    /// Turns the page every few seconds until the last page, a sheet, or the slider stops it.
    public func setAutoPlay(_ policy: ReaderAutoPlayPolicy) {
        autoPlayTask?.cancel()
        autoPlayTask = nil
        if autoPlay != policy {
            autoPlay = policy
        }
        guard let seconds = policy.seconds else { return }
        autoPlayTask = Task { [weak self, clock] in
            while true {
                do {
                    try await clock.sleep(for: .seconds(seconds))
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                if engine?.advance() != true {
                    // Legacy kept the timer running at the end of the gallery.
                    autoPlayTask = nil
                    autoPlay = .off
                    return
                }
            }
        }
    }

    // MARK: Menu

    public func showSettings() {
        destination = .settings
    }

    /// Legacy "Reload all images": forgets every URL of the gallery, in memory and stored,
    /// and resolves the pages from scratch.
    public func reloadAllImages() {
        resolver.reset()
        previews.reset()
        previewURLs = [:]
        failedImagePages = []
        staleCandidates = []
        sizedPages = []
        writer.deletePages()
        engine?.reloadData()
    }

    /// Legacy "Retry all failed images": every failed page and preview goes back to idle.
    /// A page whose image failed loads the same URL again; a page that failed to resolve is
    /// resolved when it is in reach.
    public func retryAllFailedImages() {
        resolver.retryAllFailed()
        let pages = failedImagePages
        failedImagePages = []
        for page in pages.sorted() {
            engine?.reloadPage(page)
        }
        previews.retryFailed()
    }
}
