import EhCore
import EhFeatures
import SwiftUI

/// Close, the gallery's title with where the slider is, and More.
struct ReaderTopBar: View {
    let model: ReaderModel
    let isLandscape: Bool
    let close: () -> Void

    private static let spacing: CGFloat = 10

    var body: some View {
        // No wider than the gaps, so the three shapes stay apart rather than melt together.
        GlassGroup(spacing: Self.spacing) {
            HStack(spacing: Self.spacing) {
                ReaderCloseButton(action: close)
                ReaderTitleCapsule(model: model)
                    .frame(maxWidth: ReaderPanelStyle.maximumTitleWidth)
                    // Centred between the buttons on a window too wide for it.
                    .frame(maxWidth: .infinity)
                ReaderMoreMenu(model: model, isLandscape: isLandscape)
            }
        }
        .padding(.horizontal, Tokens.Spacing.large)
        .padding(.top, Tokens.Spacing.xSmall)
    }
}

/// "Morning Light Sketchbook" over "Page 12 of 64 · 52 left": the title the detail page shows,
/// and the page, which follows the slider, so it shows the page being scrubbed to.
private struct ReaderTitleCapsule: View {
    let model: ReaderModel

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(model.title(prefersJapanese: settings.displaysJapaneseTitle))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ReaderPanelStyle.primary)
            Text(L10n.Localizable.ReadingView.Title.pagePosition(
                model.sliderPage, model.pageCount, model.sliderPagesLeft
            ))
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(ReaderPanelStyle.secondary)
        }
        .lineLimit(1)
        .padding(.horizontal, 18)
        .padding(.vertical, Tokens.Spacing.xSmall)
        .frame(maxWidth: .infinity, minHeight: ReaderPanelStyle.controlHeight, alignment: .leading)
        .contentShape(.capsule)
        .glassSurface(in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

/// Everything the labelled buttons of the bottom panel do not hold: the reload commands and,
/// where dual pages can show, their two settings.
private struct ReaderMoreMenu: View {
    let model: ReaderModel
    let isLandscape: Bool

    @Environment(SettingsStore.self) private var settings

    private typealias Strings = L10n.Localizable.ReadingView.ToolbarItem

    var body: some View {
        @Bindable var settings = settings
        Menu {
            Button(Strings.Button.retryAllFailedImages, systemImage: "exclamationmark.arrow.triangle.2.circlepath") {
                model.retryAllFailedImages()
            }
            Button(Strings.Button.reloadAllImages, systemImage: "arrow.counterclockwise") {
                model.reloadAllImages()
            }
            // Legacy: only where dual pages can show, in landscape and not in the strip.
            if isLandscape, settings.readingDirection != .vertical {
                Section {
                    Toggle(Strings.Title.dualPageMode, isOn: $settings.enablesDualPageMode)
                    Toggle(Strings.Title.exceptTheCover, isOn: $settings.exceptCover)
                        .disabled(!settings.enablesDualPageMode)
                }
            }
        } label: {
            // The symbol carries the system's localized "More" label for VoiceOver.
            ReaderCircleLabel(systemImage: "ellipsis")
        }
        .buttonStyle(.plain)
    }
}
