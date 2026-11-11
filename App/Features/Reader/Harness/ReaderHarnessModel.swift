#if DEBUG
import EhFeatures
import Observation
import UIKit

/// The host side of the reader harness: a made-up gallery whose page URLs "resolve" after a
/// delay and sometimes fail, so every state of the engine can be reached by hand.
///
/// Page states live outside observation on purpose. The engine asks for them when it needs
/// them and is told about changes page by page through the proxy, which is exactly how the real
/// reader model is meant to drive it.
@Observable
final class ReaderHarnessModel: ReaderEngineDataSource, ReaderEngineDelegate {
    var configuration = ReaderConfiguration()
    private(set) var pageCount = 60
    private(set) var currentPage = 1
    var isPanelVisible = true
    /// Seconds a page takes to resolve its URL, and again to download its image.
    var latency = 0.8
    /// Whether the host hands the engine aspect ratios before the images load.
    var knowsAspectRatios = false {
        didSet {
            if knowsAspectRatios != oldValue {
                proxy.reloadData()
            }
        }
    }
    /// Seconds between automatic page turns; 0 is off.
    var autoAdvanceInterval = 0.0 {
        didSet { restartAutoAdvance() }
    }
    private(set) var events: [String] = []

    @ObservationIgnored let proxy = ReaderEngineProxy()
    @ObservationIgnored private var states: [Int: ReaderPageState] = [:]
    @ObservationIgnored private var resolving: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var attempts: [Int: Int] = [:]
    @ObservationIgnored private var autoAdvance: Task<Void, Never>?
    /// Fresh URLs every time the harness opens, so images download again instead of coming
    /// from the disk cache.
    @ObservationIgnored private let session = UUID().uuidString.prefix(8).lowercased()

    init() {
        ReaderHarnessURLProtocol.install()
    }

    // MARK: Controls

    func setPageCount(_ count: Int) {
        guard count != pageCount else { return }
        pageCount = count
        resetPages()
    }

    /// Forgets every resolved URL, like the legacy "reload all images".
    func resetPages() {
        resolving.values.forEach { $0.cancel() }
        resolving = [:]
        states = [:]
        attempts = [:]
        proxy.reloadData()
    }

    func clearImageCache() {
        ImagePipeline.cache.clearCache()
        log("image cache cleared")
    }

    func stop() {
        autoAdvance?.cancel()
        resolving.values.forEach { $0.cancel() }
    }

    /// Resolution fails once for every seventh page; the image fails once for every eleventh.
    static func failsResolutionFirst(_ page: Int) -> Bool { page % 7 == 0 }
    static func failsImageFirst(_ page: Int) -> Bool { page % 11 == 0 }

    // MARK: ReaderEngineDataSource

    func pageState(at page: Int) -> ReaderPageState {
        states[page] ?? .pending
    }

    func aspectRatio(at page: Int) -> CGFloat? {
        knowsAspectRatios ? ReaderHarnessImages.spec(forPage: page).aspectRatio : nil
    }

    // MARK: ReaderEngineDelegate

    func readerDidChangeCurrentPage(_ page: Int) {
        currentPage = page
    }

    func readerNeedsPages(_ pages: [Int]) {
        for page in pages where pageState(at: page) == .pending {
            resolve(page)
        }
    }

    func readerNoLongerNeedsPages(_ pages: [Int]) {
        for page in pages {
            resolving.removeValue(forKey: page)?.cancel()
        }
    }

    func readerDidRequestRetry(page: Int) {
        log("retry page \(page)")
        attempts[page, default: 0] += 1
        states[page] = .pending
        proxy.reloadPage(page)
        resolve(page)
    }

    func readerDidLoadImage(page: Int, pixelSize: CGSize) {
        log("loaded page \(page) at \(Int(pixelSize.width))×\(Int(pixelSize.height))")
    }

    func readerDidFailToLoadImage(page: Int) {
        log("image of page \(page) failed")
    }

    func readerDidTapToTogglePanel() {
        isPanelVisible.toggle()
    }

    func readerContextMenu(for page: Int) -> UIMenu? {
        typealias Strings = L10n.Localizable.ReadingView.ContextMenu.Button
        var actions = [
            UIAction(title: Strings.reload, image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
                self?.readerDidRequestRetry(page: page)
            }
        ]
        if case .image(let url) = pageState(at: page) {
            let entries = [
                (Strings.copy, "plus.square.on.square"),
                (Strings.save, "square.and.arrow.down"),
                (Strings.saveOriginal, "square.and.arrow.down.on.square"),
                (Strings.share, "square.and.arrow.up")
            ]
            actions += entries.map { title, symbol in
                UIAction(title: title, image: UIImage(systemName: symbol)) { [weak self] _ in
                    self?.reportOriginal(of: url, page: page, action: title)
                }
            }
        }
        return UIMenu(children: actions)
    }

    // MARK: Private

    private func resolve(_ page: Int) {
        guard resolving[page] == nil else { return }
        let delay = latency * Double.random(in: 0.5...1.5)
        resolving[page] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            resolving[page] = nil
            let attempt = attempts[page, default: 0]
            if Self.failsResolutionFirst(page), attempt == 0 {
                states[page] = .failed
            } else if let url = ReaderHarnessURLProtocol.url(
                forPage: page, session: session, attempt: attempt, latency: latency,
                fails: Self.failsImageFirst(page) && attempt == 0
            ) {
                states[page] = .image(url)
            } else {
                states[page] = .failed
            }
            proxy.reloadPage(page)
        }
    }

    /// Shows that the untouched original is still on disk for the host to save or share.
    private func reportOriginal(of url: URL, page: Int, action: String) {
        Task { [weak self] in
            let bytes = await ImagePipeline.originalData(for: url)?.count
            self?.log("\(action) page \(page): original " + (bytes.map { "\($0 / 1_024) KB on disk" } ?? "missing"))
        }
    }

    private func restartAutoAdvance() {
        autoAdvance?.cancel()
        autoAdvance = nil
        let interval = autoAdvanceInterval
        guard interval > 0 else { return }
        autoAdvance = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let self else { return }
                if !proxy.advance() {
                    autoAdvanceInterval = 0
                    return
                }
            }
        }
    }

    private func log(_ event: String) {
        events.append(event)
        if events.count > 4 {
            events.removeFirst(events.count - 4)
        }
    }
}
#endif
