import EhFeatures
import UIKit

/// Connects the reader engine to `ReaderModel`: the engine's questions and events go to the
/// model, the model's commands go to the engine through the proxy. It decides nothing.
///
/// The engine holds its data source and delegate weakly; the screen keeps this object alive.
final class ReaderEngineBridge: ReaderEngineDataSource, ReaderEngineDelegate {
    let proxy = ReaderEngineProxy()
    private let model: ReaderModel

    init(model: ReaderModel) {
        self.model = model
        let proxy = proxy
        model.engine = ReaderEngineCommands(
            reloadPage: { proxy.reloadPage($0) },
            reloadData: { proxy.reloadData() },
            scrollToPage: { proxy.scrollToPage($0) },
            advance: { proxy.advance() }
        )
    }

    // MARK: ReaderEngineDataSource

    var pageCount: Int { model.pageCount }

    func pageState(at page: Int) -> ReaderPageState {
        model.pageState(at: page)
    }

    func aspectRatio(at page: Int) -> CGFloat? {
        model.aspectRatio(at: page)
    }

    // MARK: ReaderEngineDelegate

    func readerDidChangeCurrentPage(_ page: Int) {
        model.currentPageDidChange(page)
    }

    func readerNeedsPages(_ pages: [Int]) {
        model.pagesNeeded(pages)
    }

    func readerNoLongerNeedsPages(_ pages: [Int]) {
        model.pagesNoLongerNeeded(pages)
    }

    func readerDidRequestRetry(page: Int) {
        model.retry(page: page)
    }

    func readerDidLoadImage(page: Int, pixelSize: CGSize) {
        model.imageDidLoad(page: page, pixelSize: pixelSize)
    }

    func readerDidFailToLoadImage(page: Int) {
        model.imageDidFail(page: page)
    }

    func readerDidTapToTogglePanel() {
        model.togglePanel()
    }

    func readerContextMenu(for page: Int) -> UIMenu? {
        let actions = model.imageActions(for: page).map { action in
            UIAction(title: action.localizedName, image: UIImage(systemName: action.symbolName)) { [weak model] _ in
                model?.perform(action, page: page)
            }
        }
        return UIMenu(children: actions)
    }
}
