import EhCore
import EhModels
import SwiftUI

/// A gallery as a grid card: cover, then its category, title, optional tags, language, pages
/// and rating (legacy `GalleryThumbnailCell`).
///
/// Covers share one 8:11 box so the grid can stay lazy; legacy's waterfall showed each cover at
/// its own height, which needs every cover measured up front.
struct GalleryThumbnailCell: View {
    let gallery: Gallery

    @Environment(SettingsStore.self) private var settings

    /// The widest a grid column gets; covers are decoded at this width.
    static let maximumWidth: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: gallery.coverURL, width: Self.maximumWidth, aspectRatio: Tokens.Aspect.cover, cornerRadius: 0)
            VStack(alignment: .leading, spacing: 5) {
                // Below the cover rather than on it: a dot and plain text cannot be read on
                // every cover.
                CategoryLabel(gallery.category.localizedName, color: gallery.color(for: settings.galleryHost))
                Text(gallery.title)
                    .font(.callout.bold())
                    .lineLimit(3, reservesSpace: true)
                if settings.showsTagsInList {
                    let tags = gallery.tagContents(maximum: settings.listTagsNumberMaximum)
                    if !tags.isEmpty {
                        ListTagCloud(tags: tags)
                    }
                }
                GalleryLanguageAndPages(gallery: gallery)
                RatingStars(rating: Double(gallery.rating))
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            .padding(Tokens.Spacing.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
