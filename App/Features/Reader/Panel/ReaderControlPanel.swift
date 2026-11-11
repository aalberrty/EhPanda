import EhCore
import EhFeatures
import SwiftUI

/// The reader's controls, floating over the page as glass (legacy `ControlPanel`): a bar at
/// the top, the slider at the bottom. A tap in the middle of the page shows and hides them.
///
/// The bars stay in the hierarchy while hidden, transparent and closed to touches, as in
/// legacy. Taking them out would pull the slider or an open menu away from under a finger
/// when a second finger taps the page. A fully transparent layer is not drawn, so the hidden
/// panel does not cost the reader its glass.
struct ReaderControlPanel: View {
    let model: ReaderModel

    @Environment(\.dismiss) private var dismiss
    /// Wider than tall, which is when the engine shows dual pages.
    @State private var isLandscape = false
    @State private var dismissals = 0

    var body: some View {
        let isShown = model.showsPanel
        VStack(spacing: 0) {
            ReaderTopBar(model: model, isLandscape: isLandscape, close: close)
                .offset(y: isShown ? 0 : -50)
            Spacer(minLength: 0)
            // Legacy: no slider for a single page.
            if model.pageCount > 1 {
                ReaderBottomBar(model: model, isLandscape: isLandscape, close: close)
                    .offset(y: isShown ? 0 : 50)
            }
        }
        .opacity(isShown ? 1 : 0)
        .allowsHitTesting(isShown)
        .accessibilityHidden(!isShown)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isLandscape = $0 }
        .animation(.default, value: isShown)
        .sensoryFeedback(.impact(weight: .light), trigger: dismissals)
    }

    private func close() {
        dismissals += 1
        dismiss()
    }
}

/// Close on a glass circle. The symbol carries the system's localized "Close" label.
struct ReaderCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassSurface(in: .circle, isInteractive: true)
    }
}

// MARK: - Top bar

private struct ReaderTopBar: View {
    let model: ReaderModel
    let isLandscape: Bool
    let close: () -> Void

    var body: some View {
        GlassGroup(spacing: Tokens.Spacing.medium) {
            HStack(spacing: Tokens.Spacing.medium) {
                ReaderCloseButton(action: close)
                ReaderPageIndicator(model: model)
                Spacer(minLength: 0)
                ReaderToolGroup(model: model, isLandscape: isLandscape)
            }
        }
        .padding(.horizontal, Tokens.Spacing.large)
        .padding(.top, Tokens.Spacing.xSmall)
    }
}

/// "current / total". It follows the slider, so it shows the page being scrubbed to.
private struct ReaderPageIndicator: View {
    let model: ReaderModel

    var body: some View {
        Text(verbatim: "\(max(model.sliderPage, 1)) / \(model.pageCount)")
            .font(.headline)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, Tokens.Spacing.large)
            .frame(height: 44)
            .contentShape(.capsule)
            .glassSurface(in: .capsule)
    }
}

/// Live Text, dual pages, auto-play and the "more" menu in one glass capsule.
private struct ReaderToolGroup: View {
    @Bindable var model: ReaderModel
    let isLandscape: Bool

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        HStack(spacing: Tokens.Spacing.xLarge) {
            Button {
                model.isLiveTextEnabled.toggle()
            } label: {
                Image(systemName: model.isLiveTextEnabled ? "viewfinder.circle.fill" : "viewfinder.circle")
            }
            // There is no localized name for it yet; "Live Text" is the system's own term.
            .accessibilityLabel(Text(verbatim: "Live Text"))
            .accessibilityAddTraits(model.isLiveTextEnabled ? .isSelected : [])
            // The system analyzer is missing on some devices and in the simulator.
            .disabled(!ReaderLiveText.isSupported)

            // Legacy: only where dual pages can show, in landscape and not in the strip.
            if isLandscape, settings.readingDirection != .vertical {
                ReaderDualPageMenu()
            }

            Menu {
                // The section gives the menu its "Auto-Play" heading, as in legacy.
                Section(L10n.Localizable.ReadingView.ToolbarItem.Title.autoPlay) {
                    Picker(L10n.Localizable.ReadingView.ToolbarItem.Title.autoPlay, selection: autoPlay) {
                        ForEach(ReaderAutoPlayPolicy.allCases) { policy in
                            Text(policy.localizedName).tag(policy)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            } label: {
                Image(systemName: "timer")
            }
            .accessibilityLabel(L10n.Localizable.ReadingView.ToolbarItem.Title.autoPlay)

            ToolbarFeaturesMenu {
                Button(
                    L10n.Localizable.ReadingView.ToolbarItem.Button.retryAllFailedImages,
                    systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                ) { model.retryAllFailedImages() }
                Button(
                    L10n.Localizable.ReadingView.ToolbarItem.Button.reloadAllImages,
                    systemImage: "arrow.counterclockwise"
                ) { model.reloadAllImages() }
                Button(L10n.Localizable.ReadingView.ToolbarItem.Button.readingSetting, systemImage: "gear") {
                    model.showSettings()
                }
            }
        }
        .font(.title3)
        .tint(.primary)
        .padding(.horizontal, Tokens.Spacing.xLarge)
        .frame(height: 44)
        .contentShape(.capsule)
        .glassSurface(in: .capsule, isInteractive: true)
    }

    private var autoPlay: Binding<ReaderAutoPlayPolicy> {
        Binding(get: { model.autoPlay }, set: { model.setAutoPlay($0) })
    }
}

/// The two dual-page settings, which legacy only offers here.
private struct ReaderDualPageMenu: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Menu {
            Toggle(L10n.Localizable.ReadingView.ToolbarItem.Title.dualPageMode, isOn: $settings.enablesDualPageMode)
            Toggle(L10n.Localizable.ReadingView.ToolbarItem.Title.exceptTheCover, isOn: $settings.exceptCover)
                .disabled(!settings.enablesDualPageMode)
        } label: {
            Image(systemName: settings.enablesDualPageMode ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
        }
        .accessibilityLabel(L10n.Localizable.ReadingView.ToolbarItem.Title.dualPageMode)
    }
}
