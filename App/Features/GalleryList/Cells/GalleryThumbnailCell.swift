import EhCore
import EhModels
import SwiftUI

/// A gallery in the cover grid: a large cover, one quiet line with its category and page
/// count, then the title. Everything else is in the long-press peek and the Detail mode.
///
/// Every cover shares one 8:11 box and every title reserves two lines, so the cells of a row
/// line up and the grid stays lazy.
struct GalleryThumbnailCell: View {
    let gallery: Gallery
    /// The width covers are decoded at: the grid's column width.
    let coverWidth: CGFloat

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListCover(url: gallery.coverURL, decodeWidth: coverWidth)
            HStack(spacing: Tokens.Spacing.xSmall) {
                // Below the cover rather than on it: a dot and plain text cannot be read on
                // every cover.
                CategoryLabel(
                    gallery.category.localizedName, color: gallery.color(for: settings.galleryHost), font: .caption
                )
                Spacer(minLength: 0)
                PageCountLabel(count: gallery.pageCount)
            }
            .padding(.top, Tokens.Spacing.small)
            Text(gallery.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2, reservesSpace: true)
                .padding(.top, 3)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// A list cover: the 8:11 box decoded at `decodeWidth`, with the faint edge that lifts it off
/// the ground. The grid and the peek decode at the same width, so they share one cached bitmap.
struct ListCover: View {
    let url: URL?
    let decodeWidth: CGFloat

    /// Larger than the row covers' `Tokens.Radius.image`, as drawn for the two-across covers.
    static let cornerRadius: CGFloat = 10

    var body: some View {
        RemoteImage(url: url, width: decodeWidth, aspectRatio: Tokens.Aspect.cover, cornerRadius: Self.cornerRadius)
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(.coverEdge, lineWidth: 1)
            }
    }
}

/// "▣ 64": the page count with a stacked-pages symbol, read as "64 pages".
struct PageCountLabel: View {
    let count: Int
    var font: Font = .caption

    var body: some View {
        HStack(spacing: Tokens.Spacing.xSmall) {
            Image(systemName: "square.on.square")
                .imageScale(.small)
            Text(count, format: .number)
                .monospacedDigit()
        }
        .font(font)
        .foregroundStyle(.textSecondary)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Localizable.Common.Value.pages("\(count)"))
    }
}

private struct GalleryThumbnailCellPreview: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 20) {
            ForEach(GalleryListPreviewData.galleries) { gallery in
                GalleryThumbnailCell(gallery: gallery, coverWidth: 180)
            }
        }
        .padding(.horizontal, Tokens.Spacing.large)
        .background(.ground)
    }
}

#Preview {
    SchemePreview { GalleryThumbnailCellPreview() }
        .environment(GalleryListPreviewData.settings)
}
