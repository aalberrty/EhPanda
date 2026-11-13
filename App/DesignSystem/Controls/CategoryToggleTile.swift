import SwiftUI

/// A category in a grid of switches (the Filters sheet, the site's front page setting).
///
/// It draws the category mark as the Search tab's category chips do: while on, the colour dot
/// and the name on a chip fill; while off, a ring in the category colour, the name struck
/// through in the tertiary colour and an outline instead of the fill. It replaces legacy's
/// white text on a coloured tile that dimmed when off.
struct CategoryToggleTile: View {
    private let name: String
    private let color: Color
    private let isOn: Bool
    private let action: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 8
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 32

    init(_ name: String, color: Color, isOn: Bool, action: @escaping () -> Void) {
        self.name = name
        self.color = color
        self.isOn = isOn
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                dot
                Text(name)
                    .strikethrough(!isOn)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isOn ? Color.textPrimary : .textTertiary)
            .padding(.horizontal, Tokens.Spacing.small)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                if isOn {
                    Capsule().fill(.chipFill)
                } else {
                    Capsule().strokeBorder(.hairline, lineWidth: 1)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// The vivid (light appearance) category colour, as `CategoryLabel` draws it. The ring
    /// resolves in the real appearance, so it contrasts with the ground.
    private var dot: some View {
        Group {
            if isOn {
                Circle()
                    .fill(color)
                    .environment(\.colorScheme, .light)
                    .overlay { Circle().strokeBorder(DesignColors.categoryRing, lineWidth: 1) }
            } else {
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .environment(\.colorScheme, .light)
            }
        }
        .frame(width: dotSize, height: dotSize)
    }
}

private struct CategoryToggleTilePreview: View {
    @State private var off: Set<String> = ["Manga", "Western"]
    private let names = ["Doujinshi", "Manga", "Artist CG", "Game CG", "Western", "Non-H", "Image Set", "Cosplay"]

    var body: some View {
        Form {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100))]) {
                ForEach(names, id: \.self) { name in
                    CategoryToggleTile(name, color: Color("E-Hentai/\(name)"), isOn: !off.contains(name)) {
                        if off.contains(name) { off.remove(name) } else { off.insert(name) }
                    }
                }
            }
            .raisedRows()
        }
        .screenGround(.grouped)
    }
}

#Preview {
    CategoryToggleTilePreview()
}
