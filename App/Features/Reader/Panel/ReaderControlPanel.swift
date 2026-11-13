import EhCore
import EhFeatures
import SwiftUI

/// The reader's controls, floating over the page as glass (legacy `ControlPanel`): close, the
/// title and More at the top, one panel with the slider and the reading buttons at the bottom.
/// A tap in the middle of the page shows and hides them.
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
            ReaderBottomPanel(model: model, isLandscape: isLandscape, close: close)
                .offset(y: isShown ? 0 : 50)
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

/// A symbol on a glass circle, the size of a control: Close and More.
struct ReaderCircleLabel: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(ReaderPanelStyle.primary)
            .frame(width: ReaderPanelStyle.controlHeight, height: ReaderPanelStyle.controlHeight)
            .contentShape(.circle)
            .glassSurface(in: .circle, isInteractive: true)
    }
}

/// Close on a glass circle. The symbol carries the system's localized "Close" label.
struct ReaderCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ReaderCircleLabel(systemImage: "xmark")
        }
        .buttonStyle(.plain)
    }
}
