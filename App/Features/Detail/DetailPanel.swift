import SwiftUI

// The pieces the detail page's glass panels share (E-Detail): the section header with its
// optional count and "Show all", and the button styles of controls drawn inside the glass.
// Controls inside a panel are not glass themselves: glass stays on the page's few large surfaces.

/// Insets of the detail page's panels.
enum DetailMetrics {
    /// Between the panels and the screen edges.
    static let pageMargin: CGFloat = Tokens.Spacing.large
    /// Between one panel and the next.
    static let panelSpacing: CGFloat = Tokens.Spacing.medium
    /// Inside a panel, before its content.
    static let panelInset: CGFloat = 14
    /// How far the hero reaches up into the navigation bar: a little less than the bar is
    /// tall on iOS 18 (44 pt) and on iOS 26, so the cover's top sits beside the bar's buttons.
    static let heroRise: CGFloat = 40
}

/// "Previews", "Comments 3": a serif section title, an optional count in the text font, and
/// "Show all" on the trailing edge when there is more to see.
struct DetailPanelHeader: View {
    let title: String
    var count: Int?
    var showsAll = false
    var showAll: () -> Void = {}

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.small) {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let count {
                Text(count, format: .number)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Tokens.Spacing.small)
            if showsAll {
                Button(action: showAll) {
                    HStack(spacing: Tokens.Spacing.xxSmall) {
                        Text(L10n.Localizable.SubSection.Button.showAll)
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                    // A 44 pt target without making the header taller.
                    .padding(.vertical, Tokens.Spacing.medium)
                    .padding(.leading, Tokens.Spacing.large)
                    .contentShape(.rect)
                    .padding(.vertical, -Tokens.Spacing.medium)
                }
                .buttonStyle(.plain)
            }
        }
        .lineLimit(1)
    }
}

/// A control drawn on a glass panel: the label alone at rest, a soft capsule of fill while pressed.
/// Disabled controls keep their label as it is, so the figures they show stay readable.
struct PanelPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.capsule)
            .background {
                Capsule()
                    .fill(.chipFill)
                    .opacity(configuration.isPressed ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A full-width capsule button inside a panel, such as "Post comment": a fill rather than
/// glass on glass.
struct PanelFillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.chipFill, in: .capsule)
            .contentShape(.capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.45)
    }
}
