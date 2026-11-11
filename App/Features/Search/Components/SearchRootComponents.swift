import EhFeatures
import EhModels
import SwiftUI

/// Keyword rows: one column of 10 in compact width, two alternating columns of 20 in regular
/// width (legacy `DoubleVerticalKeywordsStack`).
struct KeywordColumns: View {
    let keywords: [SearchKeyword]
    let isRegularWidth: Bool
    let search: (String) -> Void
    /// Shows a remove button on each row when given.
    let remove: ((String) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.xxLarge) {
            let columns = SearchRootModel.columns(keywords, isRegularWidth: isRegularWidth)
            ForEach(columns.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                    ForEach(columns[index], id: \.self) { keyword in
                        KeywordRow(keyword: keyword, search: search, remove: remove)
                        if keyword != columns[index].last {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .padding()
    }
}

private struct KeywordRow: View {
    let keyword: SearchKeyword
    let search: (String) -> Void
    let remove: ((String) -> Void)?

    var body: some View {
        HStack(spacing: Tokens.Spacing.xLarge) {
            Button {
                search(keyword.keyword)
            } label: {
                Label {
                    Text(keyword.title)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
                .contentShape(.rect)
            }
            .tint(.primary)

            if let remove {
                Button {
                    remove(keyword.keyword)
                } label: {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, minHeight: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Localizable.ConfirmationDialog.Button.remove)
            }
        }
    }
}

/// Recently opened galleries in a horizontal row (legacy `GalleryHistoryCell`).
struct RecentGalleries: View {
    let galleries: [Gallery]
    let open: (Gallery) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Tokens.Spacing.large) {
                ForEach(galleries) { gallery in
                    Button { open(gallery) } label: {
                        RecentGalleryCell(gallery: RecentGalleryCell.Content(gallery))
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }
}

private struct RecentGalleryCell: View, Equatable {
    struct Content: Equatable {
        let title: String
        let uploader: String?
        let rating: Float
        let coverURL: URL?

        init(_ gallery: Gallery) {
            title = gallery.trimmedTitle
            uploader = gallery.uploader
            rating = gallery.rating
            coverURL = gallery.coverURL
        }
    }

    let gallery: Content

    // Legacy: three row-cover widths wide and three quarters of a row cover high.
    private static let coverSize = CGSize(
        width: Tokens.ImageSize.row.width * 0.75, height: Tokens.ImageSize.row.height * 0.75
    )
    private static let width = Tokens.ImageSize.row.width * 3

    var body: some View {
        HStack(spacing: Tokens.Spacing.xLarge) {
            RemoteImage(url: gallery.coverURL, size: Self.coverSize, contentMode: .fill, cornerRadius: 2)
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                Text(gallery.title)
                    .bold()
                    .lineLimit(2)
                if let uploader = gallery.uploader {
                    Text(uploader)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                RatingStars(rating: Double(gallery.rating))
            }
            .font(.caption)
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        // Grows past the cover height only for large Dynamic Type sizes.
        .frame(width: Self.width)
        .frame(minHeight: Self.coverSize.height)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
