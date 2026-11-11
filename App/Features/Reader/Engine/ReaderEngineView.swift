import EhFeatures
import SwiftUI

/// The reader engine as a SwiftUI view.
///
/// Data flows one way in each direction, which is what keeps SwiftUI and the engine from
/// fighting over the scroll position:
/// - Down, as values: `configuration`. Changing it reconfigures the engine in place.
/// - Down, as commands: `ReaderEngineProxy`. "Go to page 37" is something that happens once,
///   not a state to keep in sync, so there is no page binding. A binding would be written by
///   the engine while it scrolls and read back on the next update as an order to scroll.
/// - Up, as events: the delegate, including the current page.
///
/// ```swift
/// @State private var reader = ReaderEngineProxy()
///
/// ReaderEngineView(configuration: configuration, proxy: reader, dataSource: adapter, delegate: adapter)
///     .ignoresSafeArea()
/// // later: reader.scrollToPage(37)
/// ```
struct ReaderEngineView: UIViewControllerRepresentable {
    var configuration: ReaderConfiguration
    /// The page to open on. Only read when the engine is created.
    var initialPage = 1
    var proxy: ReaderEngineProxy
    /// Held weakly by the engine: whoever owns the reader's state keeps these alive.
    var dataSource: any ReaderEngineDataSource
    var delegate: any ReaderEngineDelegate

    func makeUIViewController(context: Context) -> ReaderEngineViewController {
        let controller = ReaderEngineViewController(configuration: configuration, initialPage: initialPage)
        controller.delegate = delegate
        controller.dataSource = dataSource
        proxy.attach(to: controller)
        return controller
    }

    func updateUIViewController(_ controller: ReaderEngineViewController, context: Context) {
        // Each of these does nothing when the value is the one the engine already has.
        controller.delegate = delegate
        controller.dataSource = dataSource
        controller.apply(configuration)
        proxy.attach(to: controller)
    }
}

/// Sends commands to a `ReaderEngineView`. Create one, keep it in `@State`, and pass it to the
/// view. Commands sent before the view exists are not lost: a page to go to is remembered and
/// applied when the engine attaches, and reloads are unnecessary then because a new engine
/// reads everything anyway.
final class ReaderEngineProxy {
    private weak var engine: ReaderEngineViewController?
    private var pendingPage: Int?

    init() {}

    /// The page the reader is on, or `nil` while there is no reader.
    var currentPage: Int? { engine?.currentPage }

    /// Goes to a page (1-based).
    func scrollToPage(_ page: Int, animated: Bool = false) {
        guard let engine else {
            pendingPage = page
            return
        }
        engine.scrollToPage(page, animated: animated)
    }

    /// Goes to the next page or spread. Returns `false` at the end of the gallery, which is
    /// where auto-play should stop.
    @discardableResult
    func advance(animated: Bool = true) -> Bool {
        engine?.advance(animated: animated) ?? false
    }

    /// Tells the engine that a page's state or aspect ratio changed. Also retries a failed image.
    func reloadPage(_ page: Int) {
        engine?.reloadPage(page)
    }

    func reloadPages(_ pages: some Sequence<Int>) {
        guard let engine else { return }
        for page in pages {
            engine.reloadPage(page)
        }
    }

    /// Tells the engine that the page count or everything about the pages changed.
    func reloadData() {
        engine?.reloadData()
    }

    fileprivate func attach(to controller: ReaderEngineViewController) {
        guard engine !== controller else { return }
        engine = controller
        if let pendingPage {
            self.pendingPage = nil
            controller.scrollToPage(pendingPage, animated: false)
        }
    }
}
