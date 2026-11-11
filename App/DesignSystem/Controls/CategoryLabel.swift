import SwiftUI

/// A gallery category as white bold text on its colour (legacy `CategoryLabel`).
///
/// A capsule by default. Pass `cornerRadii` when the label sits in a corner of an image and only
/// some corners should round, which legacy expressed with `UIRectCorner`.
struct CategoryLabel: View {
    private let text: String
    private let color: Color
    private let font: Font
    private let insets: EdgeInsets
    private let cornerRadii: RectangleCornerRadii?

    init(
        _ text: String, color: Color, font: Font = .footnote,
        insets: EdgeInsets = EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6),
        cornerRadii: RectangleCornerRadii? = nil
    ) {
        self.text = text
        self.color = color
        self.font = font
        self.insets = insets
        self.cornerRadii = cornerRadii
    }

    var body: some View {
        Text(text)
            .font(font.bold())
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(insets)
            .background {
                if let cornerRadii {
                    UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous).fill(color)
                } else {
                    Capsule().fill(color)
                }
            }
    }
}

private struct CategoryLabelPreview: View {
    private let samples: [(String, Color)] = [
        ("Doujinshi", .red), ("Manga", .orange), ("Artist CG", .yellow), ("Game CG", .green),
        ("Western", .mint), ("Non-H", .blue), ("Image Set", .indigo), ("Cosplay", .purple),
        ("Asian Porn", .pink), ("Misc", .gray),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            FlowLayout(spacing: Tokens.Spacing.small) {
                ForEach(samples, id: \.0) { CategoryLabel($0.0, color: $0.1) }
            }
            CategoryLabel(
                "Doujinshi", color: .red, font: .headline,
                insets: EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
            )
            CategoryLabel(
                "Corner", color: .blue,
                cornerRadii: RectangleCornerRadii(bottomTrailing: Tokens.Radius.image)
            )
        }
    }
}

#Preview {
    SchemePreview { CategoryLabelPreview() }
}
