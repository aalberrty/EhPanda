import EhCore
import EhModels
import SwiftUI

/// A gallery as a list row: cover, title, uploader, optional tags, rating, language, pages,
/// category and posted date (legacy `GalleryDetailCell`).
struct GalleryDetailRow: View {
    let gallery: Gallery

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.medium) {
            RemoteImage(url: gallery.coverURL, size: Tokens.ImageSize.row)
            VStack(alignment: .leading, spacing: 5) {
                Text(gallery.title)
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let uploader = gallery.uploader, !uploader.isEmpty {
                    Text(uploader)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(.yellow)
                    Spacer()
                    GalleryLanguageAndPages(gallery: gallery)
                        .minimumScaleFactor(0.75)
                }
                HStack(alignment: .bottom) {
                    CategoryLabel(gallery.category.localizedName, color: gallery.color(for: settings.galleryHost))
                    Spacer()
                    Text(gallery.formattedDateString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(minHeight: Tokens.ImageSize.row.height)
        }
        .padding(.vertical, Tokens.Spacing.xSmall)
        .accessibilityElement(children: .combine)
    }
}

/// "English  🖼 24" in secondary footnote text.
struct GalleryLanguageAndPages: View {
    let gallery: Gallery

    var body: some View {
        HStack(spacing: 10) {
            if let language = gallery.language {
                Text(language.localizedName)
            }
            Label {
                Text(gallery.pageCount, format: .number)
            } icon: {
                Image(systemName: "photo.on.rectangle.angled")
            }
            .labelStyle(CompactLabelStyle())
            .accessibilityLabel(L10n.Localizable.Common.Value.pages("\(gallery.pageCount)"))
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// Icon and title 2 pt apart, like legacy's `HStack(spacing: 2)`.
private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Tokens.Spacing.xxSmall) {
            configuration.icon
            configuration.title
        }
    }
}
