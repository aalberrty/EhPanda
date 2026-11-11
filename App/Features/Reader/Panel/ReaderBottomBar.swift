import EhCore
import EhFeatures
import EhNetworking
import SwiftUI

/// The lower half of the control panel: a second close button within reach of the thumb
/// (swiping it down closes too), and the page slider with its preview strip.
struct ReaderBottomBar: View {
    let model: ReaderModel
    let isLandscape: Bool
    let close: () -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let isReversed = settings.readingDirection == .rightToLeft
        VStack(spacing: Tokens.Spacing.large) {
            ReaderCloseButton(action: close)
                .simultaneousGesture(DragGesture().onEnded { drag in
                    // Legacy: a downward flick of more than 30 points.
                    if drag.predictedEndTranslation.height > 30 { close() }
                })
                .opacity(model.showsSliderPreview ? 0 : 1)

            VStack(spacing: 0) {
                if model.showsSliderPreview {
                    ReaderPreviewStrip(model: model, isReversed: isReversed, isRegularWidth: sizeClass == .regular)
                        .transition(.opacity)
                }
                ReaderPageSlider(model: model, isReversed: isReversed)
            }
            .contentShape(.rect(cornerRadius: Tokens.Radius.card, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: Tokens.Radius.card, style: .continuous))
            .padding(.horizontal, Tokens.Spacing.small)
            .animation(.default, value: model.showsSliderPreview)
        }
        .padding(.bottom, Tokens.Spacing.xSmall)
        .onChange(of: stripLength, initial: true) { _, length in
            model.previewStripLength = length
        }
    }

    /// Legacy: 3 previews on iPhone, 5 on an iPad in portrait, 7 in landscape.
    private var stripLength: Int {
        guard sizeClass == .regular else { return 3 }
        return isLandscape ? 7 : 5
    }
}

/// The page slider. Right-to-left reading runs it from the right, with the end labels swapped.
private struct ReaderPageSlider: View {
    let model: ReaderModel
    let isReversed: Bool

    var body: some View {
        HStack(spacing: 0) {
            endLabel(isReversed ? model.pageCount : 1)
            ReaderSlider(
                page: model.sliderPage, pageCount: model.pageCount,
                onEditingChanged: { model.sliderEditingChanged($0) },
                onChange: { model.setSliderPage($0) }
            )
            // Mirrored for right-to-left reading (legacy turned it by 180°), so page 1 is on
            // the right and the track fills from there.
            .scaleEffect(x: isReversed ? -1 : 1, y: 1)
            // Legacy: 60 % of the window's width.
            .containerRelativeFrame(.horizontal) { width, _ in width * 0.6 }
            endLabel(isReversed ? 1 : model.pageCount)
        }
    }

    private func endLabel(_ page: Int) -> some View {
        Text(verbatim: "\(page)")
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .padding()
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

/// Thumbnails of the pages around the slider's position, shown while the slider is held.
private struct ReaderPreviewStrip: View {
    let model: ReaderModel
    let isReversed: Bool
    let isRegularWidth: Bool

    var body: some View {
        let pages = model.previewStripPages
        HStack(alignment: .top, spacing: 10) {
            ForEach(isReversed ? pages.reversed() : pages, id: \.self) { page in
                ReaderPreviewCell(
                    page: page, url: model.previewURLs[page], isCurrent: page == model.sliderPage,
                    // Places before page 1 and after the last page stay empty, as in legacy.
                    isInGallery: page >= 1 && page <= model.pageCount, isRegularWidth: isRegularWidth
                )
            }
        }
        .padding(.top, isRegularWidth ? Tokens.Spacing.xxLarge : Tokens.Spacing.xLarge)
        .padding(.horizontal, isRegularWidth ? Tokens.Spacing.large : Tokens.Spacing.medium)
    }
}

private struct ReaderPreviewCell: View, Equatable {
    let page: Int
    let url: URL?
    let isCurrent: Bool
    let isInGallery: Bool
    let isRegularWidth: Bool

    var body: some View {
        VStack(spacing: Tokens.Spacing.small) {
            thumbnail
            Text(verbatim: "\(page)")
                .font(isRegularWidth ? .callout : .caption)
                .monospacedDigit()
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
        }
        // Wide windows would otherwise stretch three thumbnails over the whole width.
        .frame(maxWidth: maximumWidth)
        .opacity(isInGallery ? 1 : 0)
        .accessibilityHidden(!isInGallery)
    }

    private var maximumWidth: CGFloat { isRegularWidth ? 140 : 110 }

    @ViewBuilder
    private var thumbnail: some View {
        if let url, let tile = CombinedPreviewURL.parse(url) {
            SpriteThumbnail(
                sheetURL: tile.plainURL,
                cropRect: CGRect(x: tile.offset, y: 0, width: tile.width, height: tile.height)
            )
        } else if let url {
            RemoteImage(url: url, width: maximumWidth, aspectRatio: Tokens.Aspect.preview)
        } else {
            ImagePlaceholder(aspectRatio: Tokens.Aspect.preview, style: .activity)
        }
    }
}
