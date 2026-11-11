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
            Slider(value: page, in: 1...Double(max(model.pageCount, 2))) { isEditing in
                model.sliderEditingChanged(isEditing)
            }
            .environment(\.layoutDirection, isReversed ? .rightToLeft : .leftToRight)
            // Legacy: 60 % of the window's width.
            .containerRelativeFrame(.horizontal) { width, _ in width * 0.6 }
            .accessibilityValue(Text(verbatim: "\(model.sliderPage) / \(model.pageCount)"))
            endLabel(isReversed ? 1 : model.pageCount)
        }
    }

    /// Not stepped: a step would draw a tick for every page.
    private var page: Binding<Double> {
        Binding(
            get: { Double(model.sliderPage) },
            set: { model.setSliderPage(Int($0.rounded())) }
        )
    }

    private func endLabel(_ page: Int) -> some View {
        Text(verbatim: "\(page)")
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .padding()
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
