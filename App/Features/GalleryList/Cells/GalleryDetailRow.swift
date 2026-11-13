import EhCore
import EhModels
import SwiftUI

/// A gallery as a list row (the Detail display mode): cover, title, uploader, optional tags,
/// rating, language, pages, category and posted date (legacy `GalleryDetailCell`).
struct GalleryDetailRow: View {
    let gallery: Gallery

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.medium) {
            // No `coverEdge` ring: the cover is letterboxed in its box, so a ring would outline
            // the empty part of the box rather than the cover.
            RemoteImage(url: gallery.coverURL, size: Tokens.ImageSize.row)
            VStack(alignment: .leading, spacing: 5) {
                Text(gallery.title)
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let uploader = gallery.uploader, !uploader.isEmpty {
                    Text(uploader)
                        .font(.subheadline)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
                if settings.showsTagsInList {
                    let tags = gallery.tagContents(maximum: settings.listTagsNumberMaximum)
                    if !tags.isEmpty {
                        ListTagCloud(tags: tags)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    RatingStars(rating: Double(gallery.rating))
                        .font(.caption)
                        .foregroundStyle(.rating)
                    Spacer()
                    GalleryLanguageAndPages(gallery: gallery)
                        .minimumScaleFactor(0.75)
                }
                HStack(alignment: .bottom) {
                    CategoryLabel(gallery.category.localizedName, color: gallery.color(for: settings.galleryHost))
                    Spacer()
                    Text(gallery.formattedDateString)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(minHeight: Tokens.ImageSize.row.height)
        }
        .padding(.vertical, Tokens.Spacing.xSmall)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// "English  ▣ 24" in secondary footnote text.
struct GalleryLanguageAndPages: View {
    let gallery: Gallery

    var body: some View {
        HStack(spacing: 10) {
            if let language = gallery.language {
                Text(language.localizedName)
            }
            PageCountLabel(count: gallery.pageCount, font: .footnote)
        }
        .font(.footnote)
        .foregroundStyle(.textSecondary)
        .lineLimit(1)
    }
}

private struct GalleryDetailRowPreview: View {
    var body: some View {
        VStack(spacing: Tokens.Spacing.medium) {
            ForEach(GalleryListPreviewData.galleries.prefix(3)) { gallery in
                GalleryDetailRow(gallery: gallery)
            }
        }
        .background(.ground)
    }
}

#Preview {
    SchemePreview { GalleryDetailRowPreview() }
        .environment(GalleryListPreviewData.settings)
}
