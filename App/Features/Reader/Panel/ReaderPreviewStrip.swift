import EhFeatures
import EhModels
import SwiftUI

/// Thumbnails of the pages around the slider's position, the slider's page in the middle,
/// shown while the slider is held.
struct ReaderPreviewStrip: View {
    let model: ReaderModel
    let isReversed: Bool
    let thumbnailSize: CGSize

    var body: some View {
        let pages = model.previewStripPages
        HStack(alignment: .top, spacing: ReaderPanelStyle.thumbnailSpacing) {
            ForEach(isReversed ? pages.reversed() : pages, id: \.self) { page in
                ReaderPreviewCell(
                    page: page, url: model.previewURLs[page], isCurrent: page == model.sliderPage,
                    // Places before page 1 and after the last page stay empty, as in legacy.
                    isInGallery: page >= 1 && page <= model.pageCount, size: thumbnailSize
                )
            }
        }
        .frame(maxWidth: .infinity)
        // Room for the ring around the current page.
        .padding(.vertical, Tokens.Spacing.xSmall)
        .accessibilityHidden(true)
    }
}

private struct ReaderPreviewCell: View, Equatable {
    let page: Int
    let url: URL?
    let isCurrent: Bool
    let isInGallery: Bool
    let size: CGSize

    var body: some View {
        VStack(spacing: 5) {
            thumbnail
                .frame(width: size.width, height: size.height)
                .overlay { edge }
            Text(verbatim: "\(page)")
                .font(.caption2.weight(isCurrent ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(isCurrent ? ReaderPanelStyle.primary : ReaderPanelStyle.secondary)
        }
        .opacity(isInGallery ? 1 : 0)
    }

    /// A hairline, or a ring set off from the current page's thumbnail.
    @ViewBuilder
    private var edge: some View {
        let radius = ReaderPanelStyle.thumbnailCornerRadius
        if isCurrent {
            RoundedRectangle(cornerRadius: radius + 3, style: .continuous)
                .strokeBorder(ReaderPanelStyle.primary, lineWidth: 2.5)
                .padding(-4.5)
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(ReaderPanelStyle.thumbnailEdge, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        let radius = ReaderPanelStyle.thumbnailCornerRadius
        if let url, let tile = CombinedPreviewURL.parse(url) {
            SpriteThumbnail(
                sheetURL: tile.plainURL,
                cropRect: CGRect(x: tile.offset, y: 0, width: tile.width, height: tile.height),
                aspectRatio: size.width / size.height, cornerRadius: radius
            )
        } else if let url {
            RemoteImage(url: url, size: size, contentMode: .fill, cornerRadius: radius)
        } else {
            ImagePlaceholder(aspectRatio: size.width / size.height, cornerRadius: radius, style: .activity)
        }
    }
}
