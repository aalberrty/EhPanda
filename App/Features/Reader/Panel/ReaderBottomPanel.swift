import EhCore
import EhFeatures
import SwiftUI

/// The lower half of the controls: one glass panel with a handle (swiping it down closes the
/// reader), the page slider with its preview strip, and the Live Text, Auto-Play and reading
/// setting buttons.
///
/// While the slider is held the strip grows the panel upward, so the slider stays under the
/// finger.
struct ReaderBottomPanel: View {
    let model: ReaderModel
    let isLandscape: Bool
    let close: () -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// How far the handle has been pulled down.
    @State private var pull: CGFloat = 0

    var body: some View {
        let isReversed = settings.readingDirection == .rightToLeft
        let shape = RoundedRectangle(cornerRadius: ReaderPanelStyle.panelCornerRadius, style: .continuous)
        VStack(spacing: 0) {
            ReaderPanelHandle(pull: $pull, close: close)
            if model.showsSliderPreview {
                ReaderPreviewStrip(
                    model: model, isReversed: isReversed,
                    thumbnailSize: ReaderPanelStyle.thumbnailSize(isLarge: isLarge)
                )
                .padding(.top, Tokens.Spacing.xSmall)
                .transition(.opacity)
            }
            // Legacy: no slider for a single page.
            if model.pageCount > 1 {
                ReaderPageSlider(model: model, isReversed: isReversed)
                    .padding(.top, Tokens.Spacing.xSmall)
            }
            ReaderPanelButtons(model: model)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, Tokens.Spacing.small)
        .frame(maxWidth: isWide ? ReaderPanelStyle.maximumPanelWidth : .infinity)
        .contentShape(shape)
        .glassSurface(in: shape)
        .animation(.default, value: model.showsSliderPreview)
        .padding(.horizontal, Tokens.Spacing.small)
        .padding(.bottom, Tokens.Spacing.xSmall)
        .offset(y: pull)
        .onChange(of: stripLength, initial: true) { _, length in
            model.previewStripLength = length
        }
    }

    /// An iPad-sized window, where the thumbnails are larger.
    private var isLarge: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    /// A window too wide for a panel from edge to edge: an iPad, or a phone in landscape.
    private var isWide: Bool {
        horizontalSizeClass == .regular || isLandscape
    }

    private var stripLength: Int {
        ReaderModel.previewStripLength(isRegularWidth: horizontalSizeClass == .regular, isLandscape: isLandscape)
    }
}

/// The grabber at the top of the panel. A downward flick closes the reader (legacy did that on
/// a second close button); a shorter pull springs back. The whole width of the panel's top edge
/// takes the swipe, not only the grabber.
private struct ReaderPanelHandle: View {
    @Binding var pull: CGFloat
    let close: () -> Void

    var body: some View {
        Capsule()
            .fill(ReaderPanelStyle.handle)
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Spacing.small)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { drag in
                        pull = max(drag.translation.height, 0)
                    }
                    .onEnded { drag in
                        // Legacy: a downward flick of more than 30 points.
                        if drag.predictedEndTranslation.height > 30 {
                            close()
                        } else {
                            withAnimation(.spring(duration: 0.3)) { pull = 0 }
                        }
                    }
            )
            // The top bar's close button is the same action for VoiceOver.
            .accessibilityHidden(true)
    }
}

/// Live Text, Auto-Play and the reading settings, each a symbol over its name.
private struct ReaderPanelButtons: View {
    let model: ReaderModel

    private typealias Strings = L10n.Localizable.ReadingView.ToolbarItem

    var body: some View {
        HStack(spacing: 0) {
            let isLiveTextOn = model.isLiveTextEnabled
            Button {
                model.isLiveTextEnabled.toggle()
            } label: {
                ReaderPanelButtonLabel(
                    title: Strings.Button.liveText,
                    systemImage: isLiveTextOn ? "viewfinder.circle.fill" : "viewfinder.circle",
                    isSelected: isLiveTextOn
                )
            }
            .accessibilityAddTraits(isLiveTextOn ? .isSelected : [])
            // The system analyzer is missing on some devices and in the simulator.
            .disabled(!ReaderLiveText.isSupported)

            Menu {
                // The section gives the menu its "Auto-Play" heading, as in legacy.
                Section(Strings.Title.autoPlay) {
                    Picker(Strings.Title.autoPlay, selection: autoPlay) {
                        ForEach(ReaderAutoPlayPolicy.allCases) { policy in
                            Text(policy.localizedName).tag(policy)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            } label: {
                ReaderPanelButtonLabel(
                    title: Strings.Title.autoPlay, systemImage: "timer", isSelected: model.autoPlay != .off
                )
            }
            .accessibilityValue(model.autoPlay.localizedName)

            Button {
                model.showSettings()
            } label: {
                ReaderPanelButtonLabel(
                    title: Strings.Button.readingSetting, systemImage: "slider.horizontal.3", isSelected: false
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var autoPlay: Binding<ReaderAutoPlayPolicy> {
        Binding(get: { model.autoPlay }, set: { model.setAutoPlay($0) })
    }
}

private struct ReaderPanelButtonLabel: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ReaderPanelStyle.buttonCornerRadius, style: .continuous)
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ReaderPanelStyle.primary)
                .frame(height: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(ReaderPanelStyle.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Tokens.Spacing.xSmall)
        .frame(maxWidth: .infinity, minHeight: ReaderPanelStyle.buttonHeight)
        .background {
            if isSelected { shape.fill(ReaderPanelStyle.selectedFill) }
        }
        .contentShape(shape)
        .opacity(isEnabled ? 1 : 0.4)
        // One element named by its title: a menu's label would otherwise offer the symbol as
        // a second button.
        .accessibilityElement(children: .combine)
    }
}
