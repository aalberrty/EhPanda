import Kingfisher
import SwiftUI

/// A one-line tag with an optional trailing image (replaces legacy `TagCloudCell`).
///
/// Legacy took a `showsImages` flag and stripped emoji from the text when images were hidden;
/// callers now pass `imageURL: nil` and the text they want shown (`GalleryTag.Content.chipText`
/// for a tag). The image is sized to the font's cap height by an invisible SF Symbol, so it
/// scales with Dynamic Type.
struct TagChip: View {
    private let text: String
    private let imageURL: URL?
    private let font: Font
    private let padding: EdgeInsets
    private let foreground: Color
    private let background: Color

    init(
        _ text: String, imageURL: URL? = nil, font: Font = .subheadline,
        padding: EdgeInsets = TagChip.defaultPadding,
        foreground: Color = .primary, background: Color = Color(.tertiarySystemFill)
    ) {
        self.text = text
        self.imageURL = imageURL
        self.font = font
        self.padding = padding
        self.foreground = foreground
        self.background = background
    }

    /// Legacy detail-screen tag padding.
    static let defaultPadding = EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14)

    var body: some View {
        HStack(spacing: Tokens.Spacing.xxSmall) {
            Text(text)
            if let imageURL {
                Image(systemName: "photo")
                    .hidden()
                    .overlay { TagChipImage(url: imageURL) }
                    .accessibilityHidden(true)
            }
        }
        .font(font.bold())
        .lineLimit(1)
        .foregroundStyle(foreground)
        .padding(padding)
        .background(background, in: .rect(cornerRadius: Tokens.Radius.chip, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct TagChipImage: View {
    @Environment(\.displayScale) private var displayScale
    let url: URL

    var body: some View {
        KFImage(url)
            // Tag images are tiny; decode them no larger than 48 pt.
            .setProcessor(DownsampleProcessor(
                pixelSize: CGSize(width: 48 * displayScale, height: 48 * displayScale), mode: .fit
            ))
            .cacheOriginalImage()
            .cacheMemoryOnly()
            .scaleFactor(displayScale)
            .cancelOnDisappear(true)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

private struct TagChipPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            HStack {
                Text(verbatim: "female")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.systemBackground))
                    .padding(TagChip.defaultPadding)
                    .background(Color(.systemGray), in: .rect(cornerRadius: Tokens.Radius.chip))
                TagChip("glasses")
                TagChip("cat", imageURL: URL(string: "https://picsum.photos/id/40/64/64"))
            }
            HStack {
                TagChip("voted up", foreground: .green, background: .green.opacity(0.15))
                TagChip("small", font: .caption, padding: EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
            }
            TagChip("Dynamic Type XXL").dynamicTypeSize(.xxxLarge)
        }
    }
}

#Preview {
    SchemePreview { TagChipPreview() }
}
