import UIKit

/// The reader's taps. Pinching and panning are the scroll views' own gestures; this adds the
/// single tap (page turn or control panel) and the double tap (zoom), and makes the single tap
/// wait for the double tap to fail so the two never both fire.
///
/// The recognisers sit on the reader's own view, so a tap is reported with its location there.
/// That replaces the legacy trick of watching every touch on the window to learn where a
/// SwiftUI tap landed.
final class ReaderGestureController: NSObject, UIGestureRecognizerDelegate {
    var onSingleTap: ((CGPoint) -> Void)?
    var onDoubleTap: ((CGPoint) -> Void)?
    /// Asked before a tap is recognised. Return `false` to leave the touch to whatever is under
    /// it, such as selectable Live Text.
    var shouldHandleTap: ((CGPoint) -> Bool)?

    private let singleTap = UITapGestureRecognizer()
    private let doubleTap = UITapGestureRecognizer()

    func install(on view: UIView) {
        doubleTap.numberOfTapsRequired = 2
        singleTap.require(toFail: doubleTap)
        for recognizer in [singleTap, doubleTap] {
            recognizer.delegate = self
            recognizer.addTarget(self, action: #selector(handleTap(_:)))
            view.addGestureRecognizer(recognizer)
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let view = recognizer.view else { return }
        let point = recognizer.location(in: view)
        if recognizer === doubleTap {
            onDoubleTap?(point)
        } else {
            onSingleTap?(point)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Buttons inside pages (retry) handle their own taps.
        !(touch.view is UIControl)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view = gestureRecognizer.view else { return true }
        return shouldHandleTap?(gestureRecognizer.location(in: view)) ?? true
    }
}
