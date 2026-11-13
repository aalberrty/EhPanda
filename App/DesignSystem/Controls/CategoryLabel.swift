import SwiftUI

/// A gallery category as a colour dot and its name in normal text, as everywhere in the
/// redesign (it replaces legacy's white bold text on a coloured pill).
///
/// The name is in `textSecondary` unless `foreground` says otherwise. The dot always uses the
/// vivid (light appearance) variant of the category colour: the dark variants were darkened
/// for white text on a pill and sink into a dark ground as a dot. A ring with at least 3:1
/// contrast against the ground outlines the dot in both appearances, so the colours closest to
/// the ground (Image Set and Cosplay in dark, Artist CG and Western in light) still show.
struct CategoryLabel: View {
    private let text: String
    private let color: Color
    private let font: Font
    private let foreground: Color

    /// The dot follows Dynamic Type with the footnote style it is drawn beside by default.
    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 8

    init(_ text: String, color: Color, font: Font = .footnote, foreground: Color = .textSecondary) {
        self.text = text
        self.color = color
        self.font = font
        self.foreground = foreground
    }

    var body: some View {
        HStack(spacing: dotSize * 0.75) {
            Circle()
                .fill(color)
                .environment(\.colorScheme, .light)
                .overlay { Circle().strokeBorder(DesignColors.categoryRing, lineWidth: 1) }
                .frame(width: dotSize, height: dotSize)
            Text(text)
                .font(font)
                .foregroundStyle(foreground)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CategoryLabelPreview: View {
    private let samples: [(String, String)] = [
        ("Doujinshi", "Doujinshi"), ("Manga", "Manga"), ("Artist CG", "Artist CG"), ("Game CG", "Game CG"),
        ("Western", "Western"), ("Non-H", "Non-H"), ("Image Set", "Image Set"), ("Cosplay", "Cosplay"),
        ("Asian Porn", "Asian Porn"), ("Misc", "Misc"), ("Private", "Private"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            ForEach(["E-Hentai", "ExHentai"], id: \.self) { host in
                FlowLayout(spacing: Tokens.Spacing.medium) {
                    ForEach(samples, id: \.0) { CategoryLabel($0.0, color: Color("\(host)/\($0.1)")) }
                }
            }
            CategoryLabel("Doujinshi", color: Color("E-Hentai/Doujinshi"), font: .subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ground)
    }
}

#Preview {
    SchemePreview { CategoryLabelPreview() }
}
