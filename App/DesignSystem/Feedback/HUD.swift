import SwiftUI

extension View {
    /// Shows a centred glass HUD while `configuration` is non-nil (replaces `TTProgressHUD`).
    ///
    /// HUDs with an `autoDismissDelay` set the binding back to `nil` themselves, unless it changed
    /// in the meantime. A loading HUD blocks touches to the content underneath, as legacy did.
    /// VoiceOver announces the title and caption.
    func hud(_ configuration: Binding<HUDConfiguration?>) -> some View {
        modifier(HUDModifier(configuration: configuration))
    }
}

private struct HUDModifier: ViewModifier {
    @Binding var configuration: HUDConfiguration?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let configuration {
                    HUDCard(configuration: configuration)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if configuration.kind == .loading {
                                Color.clear.contentShape(.rect).ignoresSafeArea()
                            }
                        }
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: configuration)
            .task(id: configuration) { await dismissAfterDelay() }
            .onChange(of: configuration, initial: true) { _, newValue in
                guard let announcement = newValue?.announcement, !announcement.isEmpty else { return }
                AccessibilityNotification.Announcement(announcement).post()
            }
    }

    private func dismissAfterDelay() async {
        guard let shown = configuration, let delay = shown.autoDismissDelay else { return }
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled, configuration == shown else { return }
        configuration = nil
    }
}

private struct HUDCard: View {
    let configuration: HUDConfiguration
    @State private var bounce = 0

    var body: some View {
        VStack(spacing: Tokens.Spacing.small) {
            icon
                .font(.largeTitle)
                .imageScale(.large)
                .symbolEffect(.bounce, value: bounce)
            if let title = configuration.title {
                Text(title).font(.headline)
            }
            if let caption = configuration.caption {
                Text(caption).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Tokens.Spacing.xxLarge)
        .padding(.vertical, Tokens.Spacing.xLarge)
        .frame(minWidth: 140, maxWidth: 280)
        .glassEffect(.regular, in: .rect(cornerRadius: Tokens.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .onAppear { bounce += 1 }
        .onChange(of: configuration) { bounce += 1 }
    }

    @ViewBuilder
    private var icon: some View {
        switch configuration.kind {
        case .loading:
            ProgressView().controlSize(.large)
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .error:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .symbol(let name):
            Image(systemName: name).foregroundStyle(.tint)
        }
    }
}

private struct HUDPreview: View {
    @State private var configuration: HUDConfiguration?

    private let presets: [(String, HUDConfiguration)] = [
        ("loading", .loading),
        ("communicating", .communicating),
        ("success", .copiedToClipboard),
        ("saved", .savedToPhotoLibrary),
        ("error", .error),
        ("error + caption", .error(caption: L10n.Localizable.ErrorView.Title.network)),
        ("symbol", .symbol("heart.fill", title: L10n.Localizable.Hud.Title.success)),
    ]

    var body: some View {
        List {
            ForEach(presets, id: \.0) { name, preset in
                Button(name) { configuration = preset }
            }
            Button(role: .destructive) { configuration = nil } label: { Text(verbatim: "dismiss") }
        }
        .hud($configuration)
    }
}

private struct HUDStaticPreview: View {
    var body: some View {
        HStack(spacing: Tokens.Spacing.medium) {
            HUDCard(configuration: .loading)
            HUDCard(configuration: .copiedToClipboard)
            HUDCard(configuration: .error)
        }
        .scaleEffect(0.6)
        .padding(.vertical, Tokens.Spacing.xLarge)
        .background(LinearGradient(colors: [.orange, .purple], startPoint: .leading, endPoint: .trailing))
    }
}

#Preview("Interactive") {
    HUDPreview()
}

#Preview("Interactive, dark") {
    HUDPreview().preferredColorScheme(.dark)
}

#Preview("Static") {
    SchemePreview { HUDStaticPreview() }
}
