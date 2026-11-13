import EhCore
import EhModels
import SwiftUI

/// The long-press peek on a cover: the cover again beside everything the grid leaves out
/// (uploader, rating, language, pages, category, posted date) and, as the list settings allow,
/// the tags. It is the preview of the cell's context menu, so it is built only when the menu
/// opens.
struct GalleryPeek: View {
    let gallery: Gallery
    /// The width the grid decodes covers at, so the peek reuses the cell's bitmap.
    let coverDecodeWidth: CGFloat
    /// The card's width; the cover takes half of it, as in the grid.
    let width: CGFloat

    @Environment(SettingsStore.self) private var settings

    private static let padding: CGFloat = Tokens.Spacing.small
    private static let spacing: CGFloat = 14

    var body: some View {
        let coverWidth = max((width - Self.padding * 2 - Self.spacing) / 2, 0)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: Self.spacing) {
                ListCover(url: gallery.coverURL, decodeWidth: coverDecodeWidth)
                    .frame(width: coverWidth)
                PinnedColumn(minHeight: coverWidth / Tokens.Aspect.cover) {
                    heading
                    facts
                }
                .padding(.top, Tokens.Spacing.xSmall)
                .padding(.trailing, 6)
            }
            if settings.showsTagsInList {
                let tags = gallery.tagContents(maximum: settings.listTagsNumberMaximum)
                if !tags.isEmpty {
                    ListTagCloud(
                        tags: tags, font: .caption,
                        padding: EdgeInsets(top: 4, leading: 7, bottom: 4, trailing: 7)
                    )
                    .padding(.bottom, Tokens.Spacing.xxSmall)
                }
            }
        }
        .padding(Self.padding)
        .frame(width: width, alignment: .leading)
        .background(.raised)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
            Text(gallery.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.textPrimary)
                .lineLimit(5)
            if let uploader = gallery.uploader, !uploader.isEmpty {
                Text(uploader)
                    .font(.footnote)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
            HStack(spacing: 6) {
                RatingStars(rating: Double(gallery.rating))
                    .foregroundStyle(.rating)
                Text(RatingStars.halfRounded(Double(gallery.rating)), format: .number.precision(.fractionLength(0...1)))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.textPrimary)
                    .accessibilityHidden(true)
            }
            .font(.footnote)
            Text(languageAndPages)
                .font(.footnote)
                .foregroundStyle(.textPrimary)
            CategoryLabel(
                gallery.category.localizedName, color: gallery.color(for: settings.galleryHost),
                foreground: .textPrimary
            )
            Text(gallery.formattedDateString)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.textTertiary)
        }
        .lineLimit(1)
    }

    /// "English · 64 pages", or only the pages when no language tag is recognised.
    private var languageAndPages: String {
        let pages = L10n.Localizable.Common.Value.pages("\(gallery.pageCount)")
        guard let language = gallery.language else { return pages }
        return language.localizedName + " · " + pages
    }
}

/// Two blocks in a column at least `minHeight` tall: the first at the top, the last at the
/// bottom, so the facts line up with the bottom of the cover beside them. Taller content grows
/// the column instead of overlapping.
private struct PinnedColumn: Layout {
    var minHeight: CGFloat
    var spacing: CGFloat = Tokens.Spacing.small

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let fitting = ProposedViewSize(width: proposal.width, height: nil)
        let sizes = subviews.map { $0.sizeThatFits(fitting) }
        let content = sizes.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(sizes.count - 1, 0))
        let width = proposal.width ?? sizes.map(\.width).max() ?? 0
        return CGSize(width: width, height: max(minHeight, content))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let fitting = ProposedViewSize(width: bounds.width, height: nil)
        guard let first = subviews.first else { return }
        first.place(at: bounds.origin, proposal: fitting)
        if subviews.count > 1, let last = subviews.last {
            last.place(at: CGPoint(x: bounds.minX, y: bounds.maxY), anchor: .bottomLeading, proposal: fitting)
        }
    }
}

/// What a long press on a gallery offers: Read, which opens the reader over the list, and Share.
struct GalleryMenuItems: View {
    let gallery: Gallery
    let read: () -> Void

    var body: some View {
        Button(L10n.Localizable.DetailView.Button.read, systemImage: "book", action: read)
        if let galleryURL = gallery.galleryURL {
            ShareLink(item: galleryURL) {
                Label(L10n.Localizable.DetailView.ToolbarItem.Button.share, systemImage: "square.and.arrow.up")
            }
        }
    }
}

#Preview {
    SchemePreview {
        GalleryPeek(gallery: GalleryListPreviewData.galleries[1], coverDecodeWidth: 180, width: 374)
    }
    .environment(GalleryListPreviewData.settings)
}
