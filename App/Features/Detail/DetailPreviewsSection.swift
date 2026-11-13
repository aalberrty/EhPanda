import EhFeatures
import EhModels
import SwiftUI

/// The previews the detail page carries, larger and in a row on a glass panel. Tapping one
/// opens the reader there; "Show all" opens every page's preview.
struct DetailPreviewsSection: View {
    let model: GalleryDetailModel

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if !model.previews.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Spacing.small + Tokens.Spacing.xxSmall) {
                DetailPanelHeader(
                    title: L10n.Localizable.DetailView.Section.Title.previews,
                    showsAll: model.showsAllPreviews,
                    showAll: { model.destination = .previews }
                )
                .padding(.leading, Tokens.Spacing.large)
                .padding(.trailing, DetailMetrics.panelInset)
                PreviewsRow(previews: model.previews, width: width) { model.openReader(page: $0) }
                    .equatable()
            }
            .padding(.top, Tokens.Spacing.medium)
            .padding(.bottom, DetailMetrics.panelInset)
            .clipShape(.rect(cornerRadius: Tokens.Radius.panel, style: .continuous))
            .glassPanel()
        }
    }

    /// The widest a grid column gets: the row shows fewer, larger previews than the grid.
    private var width: CGFloat {
        Tokens.ImageSize.previewWidths(for: sizeClass).upperBound
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
        .contentMargins(.horizontal, DetailMetrics.panelInset, for: .scrollContent)
    }
}

/// One page preview: a tile cut from a sprite sheet, a standalone image, or a placeholder.
struct PreviewThumbnailView: View, Equatable {
    let thumbnail: PreviewThumbnail?
    /// The widest the cell can be, for decoding standalone images.
    let width: CGFloat
    /// The preview could not be had; tapping the cell asks for it again (the reader's retry symbol).
    var failed = false

    var body: some View {
        switch thumbnail?.source {
        case .sprite(let sheetURL, let x, let tileWidth, let height):
            SpriteThumbnail(sheetURL: sheetURL, cropRect: CGRect(x: x, y: 0, width: tileWidth, height: height))
        case .image(let url):
            RemoteImage(url: url, width: width, aspectRatio: Tokens.Aspect.preview)
        case nil where failed:
            ImagePlaceholder(aspectRatio: Tokens.Aspect.preview, style: .plain)
                .overlay {
                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundStyle(.textSecondary)
                }
        case nil:
            ImagePlaceholder(aspectRatio: Tokens.Aspect.preview, style: .activity)
        }
    }
}
