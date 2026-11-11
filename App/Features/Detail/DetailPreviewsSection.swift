import EhFeatures
import EhModels
import SwiftUI

/// The previews the detail page carries, in a horizontal row. Tapping one opens the reader there.
struct DetailPreviewsSection: View {
    let model: GalleryDetailModel

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if !model.previews.isEmpty {
            SubSection(
                title: L10n.Localizable.DetailView.Section.Title.previews,
                showsAll: model.pageCount > 20,
                showAll: { model.destination = .previews }
            ) {
                PreviewsRow(previews: model.previews, width: width) { model.openReader(page: $0) }
                    .equatable()
            }
        }
    }

    /// Legacy used the middle of the grid's column range.
    private var width: CGFloat {
        let range = Tokens.ImageSize.previewWidths(for: sizeClass)
        return (range.lowerBound + range.upperBound) / 2
    }
}

private struct PreviewsRow: View, Equatable {
    let previews: [PreviewThumbnail]
    let width: CGFloat
    let open: (Int) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.previews == rhs.previews && lhs.width == rhs.width
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Tokens.Spacing.small) {
                ForEach(previews) { preview in
                    Button {
                        open(preview.index)
                    } label: {
                        PreviewThumbnailView(thumbnail: preview, width: width)
                            .frame(width: width)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(preview.index, format: .number))
                }
            }
            .frame(height: width / Tokens.Aspect.preview)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Tokens.Spacing.large, for: .scrollContent)
    }
}

/// One page preview: a tile cut from a sprite sheet, a standalone image, or a placeholder.
struct PreviewThumbnailView: View, Equatable {
    let thumbnail: PreviewThumbnail?
    /// The widest the cell can be, for decoding standalone images.
    let width: CGFloat
    var failed = false

    var body: some View {
        switch thumbnail?.source {
        case .sprite(let sheetURL, let x, let tileWidth, let height):
            SpriteThumbnail(sheetURL: sheetURL, cropRect: CGRect(x: x, y: 0, width: tileWidth, height: height))
        case .image(let url):
            RemoteImage(url: url, width: width, aspectRatio: Tokens.Aspect.preview)
        case nil:
            ImagePlaceholder(aspectRatio: Tokens.Aspect.preview, style: failed ? .failure : .activity)
        }
    }
}
