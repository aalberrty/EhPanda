import EhFeatures
import SwiftUI
import UIKit

/// The page slider between 1 and the page count. Right-to-left reading runs it from the right,
/// with the end labels swapped.
struct ReaderPageSlider: View {
    let model: ReaderModel
    let isReversed: Bool

    var body: some View {
        HStack(spacing: 10) {
            endLabel(isReversed ? model.pageCount : 1)
            ReaderSlider(
                page: model.sliderPage, pageCount: model.pageCount,
                onEditingChanged: { model.sliderEditingChanged($0) },
                onChange: { model.setSliderPage($0) }
            )
            // Mirrored for right-to-left reading (legacy turned it by 180°), so page 1 is on
            // the right and the track fills from there.
            .scaleEffect(x: isReversed ? -1 : 1, y: 1)
            endLabel(isReversed ? 1 : model.pageCount)
        }
        .frame(minHeight: ReaderPanelStyle.controlHeight)
        .padding(.horizontal, Tokens.Spacing.xSmall)
    }

    private func endLabel(_ page: Int) -> some View {
        Text(verbatim: "\(page)")
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(ReaderPanelStyle.secondary)
            .frame(minWidth: 20)
            .fixedSize()
            // The slider's own value says where it is and where it ends.
            .accessibilityHidden(true)
    }
}

/// The page slider as a `UISlider`.
///
/// SwiftUI's `Slider` cannot say reliably when a drag ends: on iOS 26.3 its `onEditingChanged`
/// reports `false` when the finger lifts and then `true` once more, which left the preview
/// strip up after every scrub. `UISlider`'s control events are exact. It is not stepped, as a
/// step would draw a tick for every page.
private struct ReaderSlider: UIViewRepresentable {
    let page: Int
    let pageCount: Int
    let onEditingChanged: (Bool) -> Void
    let onChange: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 1
        slider.minimumTrackTintColor = ReaderPanelStyle.sliderFill
        // The reading direction decides which way it runs, not the interface language.
        slider.semanticContentAttribute = .forceLeftToRight
        let coordinator = context.coordinator
        slider.addTarget(coordinator, action: #selector(Coordinator.touchDown), for: .touchDown)
        slider.addTarget(coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.addTarget(
            coordinator, action: #selector(Coordinator.touchUp),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.slider = self
        slider.maximumValue = Float(max(pageCount, 2))
        // The finger owns the thumb while it is down.
        if !slider.isTracking, Int(slider.value.rounded()) != page {
            slider.setValue(Float(page), animated: false)
        }
        slider.accessibilityValue = "\(page) / \(pageCount)"
    }

    final class Coordinator: NSObject {
        var slider: ReaderSlider?

        @objc func touchDown() {
            slider?.onEditingChanged(true)
        }

        @objc func valueChanged(_ control: UISlider) {
            slider?.onChange(Int(control.value.rounded()))
        }

        @objc func touchUp() {
            slider?.onEditingChanged(false)
        }
    }
}
