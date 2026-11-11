import EhFeatures
import EhModels
import SwiftUI

/// The horizontal strip of figures under the header, ending with the Gallery Infos button.
struct DetailDescriptionSection: View {
    let model: GalleryDetailModel

    var body: some View {
        if let detail = model.detail {
            DescriptionStrip(detail: detail) { model.destination = .galleryInfos }
        }
    }
}

private struct DescriptionStrip: View, Equatable {
    let detail: GalleryDetail
    let showInfos: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.detail == rhs.detail
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                item {
                    figure(
                        title: L10n.Localizable.DetailView.DescriptionSection.Title.favorited,
                        value: detail.favoritedCount.formatted(),
                        caption: L10n.Localizable.DetailView.DescriptionSection.Description.favorited
                    )
                }
                Divider()
                item {
                    figure(
                        title: L10n.Localizable.DetailView.DescriptionSection.Title.language,
                        value: detail.language.abbreviation,
                        caption: detail.language.localizedName
                    )
                }
                Divider()
                item { ratings }
                Divider()
                item {
                    figure(
                        title: L10n.Localizable.DetailView.DescriptionSection.Title.pageCount,
                        value: detail.pageCount.formatted(),
                        caption: L10n.Localizable.DetailView.DescriptionSection.Description.pageCount
                    )
                }
                Divider()
                item {
                    figure(
                        title: L10n.Localizable.DetailView.DescriptionSection.Title.fileSize,
                        value: detail.sizeCount.formatted(),
                        caption: detail.sizeType
                    )
                }
                Divider()
                item {
                    Button(action: showInfos) {
                        Image(systemName: "ellipsis")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel(L10n.Localizable.GalleryInfosView.Title.galleryInfos)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Tokens.Spacing.small, for: .scrollContent)
    }

    /// Legacy gave each item a fifth of the width, at least 80 pt.
    private func item(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .containerRelativeFrame(.horizontal, count: 5, spacing: 0)
            .frame(minWidth: 80)
    }

    private func figure(title: String, value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .combine)
    }

    private var ratings: some View {
        VStack(spacing: 3) {
            Text(L10n.Localizable.DetailView.DescriptionSection.Title.ratings(detail.ratingCount.formatted()))
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(detail.rating, format: .number.precision(.fractionLength(2)))
                .font(.title3.weight(.medium))
            RatingStars(rating: Double(detail.rating))
                .font(.caption2)
                .foregroundStyle(.yellow)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .combine)
    }
}
