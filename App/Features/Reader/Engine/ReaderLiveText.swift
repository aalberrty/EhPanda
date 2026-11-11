import UIKit
import VisionKit

/// Live Text for one page, using the system's analyzer and interaction instead of the legacy
/// Vision request and hand-drawn overlay. Recognised text is highlighted and can be selected,
/// copied, looked up and translated through the system menu.
final class ReaderLiveText {
    /// False on devices (and simulators) without Live Text.
    static var isSupported: Bool { ImageAnalyzer.isSupported }

    private static let analyzer = ImageAnalyzer()

    private let interaction = ImageAnalysisInteraction()
    private weak var imageView: UIImageView?
    private var task: Task<Void, Never>?

    init(imageView: UIImageView) {
        self.imageView = imageView
        interaction.preferredInteractionTypes = []
        imageView.addInteraction(interaction)
        // UIImageView ignores touches by default, which would starve the interaction.
        imageView.isUserInteractionEnabled = true
    }

    /// Analyses `image` in the background and turns text selection on when the result is in.
    func analyze(_ image: UIImage) {
        clear()
        task = Task { [weak self] in
            let configuration = ImageAnalyzer.Configuration([.text])
            let analysis = try? await Self.analyzer.analyze(image, configuration: configuration)
            guard !Task.isCancelled, let self, let analysis else { return }
            interaction.analysis = analysis
            interaction.preferredInteractionTypes = .textSelection
            interaction.selectableItemsHighlighted = true
        }
    }

    func clear() {
        task?.cancel()
        task = nil
        guard interaction.analysis != nil else { return }
        interaction.selectableItemsHighlighted = false
        interaction.preferredInteractionTypes = []
        interaction.analysis = nil
    }

    func detach() {
        clear()
        imageView?.removeInteraction(interaction)
        imageView?.isUserInteractionEnabled = false
    }

    /// Whether a touch at `point` (in the image view's coordinates) belongs to Live Text: it is
    /// on recognised text, or there is a selection that a tap elsewhere should dismiss.
    func wantsTouch(at point: CGPoint) -> Bool {
        guard interaction.analysis != nil else { return false }
        return interaction.hasInteractiveItem(at: point) || interaction.hasActiveTextSelection
    }
}
