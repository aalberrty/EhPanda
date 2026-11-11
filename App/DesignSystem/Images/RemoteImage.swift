import Kingfisher
import SwiftUI

/// A cover or thumbnail loaded with Kingfisher and decoded at its display size.
///
/// The caller states the size up front, so no `GeometryReader` is needed and the processor key
/// stays stable while scrolling:
/// - `init(url:size:contentMode:…)` for a fixed box, such as a list row cover;
/// - `init(url:width:aspectRatio:…)` for a view that fills the proposed width, such as a grid
///   cell. `width` is only the decode target (use the largest width the cell can reach); the view
///   itself takes the width it is offered. With a `nil` aspect ratio the height follows the image.
///
/// Originals go to the disk cache and only display-sized bitmaps to the memory cache, so the same
/// cover shown at two sizes is downloaded once. Loads are cancelled when the view disappears.
/// The image is decorative to VoiceOver; label the containing cell instead.
struct RemoteImage: View {
    private enum Sizing {
        case fixed(CGSize, SwiftUI.ContentMode)
        case width(CGFloat, aspectRatio: CGFloat?)
    }

    @Environment(\.displayScale) private var displayScale

    private let url: URL?
    private let sizing: Sizing
    private let cornerRadius: CGFloat
    private let webtoon: WebtoonCrop?

    /// A fixed box. `.fit` letterboxes inside it with the corners on the image (legacy row cover);
    /// `.fill` covers and clips it.
    init(
        url: URL?, size: CGSize, contentMode: SwiftUI.ContentMode = .fit,
        cornerRadius: CGFloat = Tokens.Radius.image, cropsWebtoon: Bool = false
    ) {
        self.url = url
        sizing = .fixed(size, contentMode)
        self.cornerRadius = cornerRadius
        webtoon = cropsWebtoon ? .standard : nil
    }

    /// Fills the proposed width. With an aspect ratio the image covers that box; without one the
    /// view takes the image's own height once loaded (legacy thumbnail grid).
    init(
        url: URL?, width: CGFloat, aspectRatio: CGFloat? = nil,
        cornerRadius: CGFloat = Tokens.Radius.image, cropsWebtoon: Bool = false
    ) {
        self.url = url
        sizing = .width(width, aspectRatio: aspectRatio)
        self.cornerRadius = cornerRadius
        webtoon = cropsWebtoon ? .standard : nil
    }

    var body: some View {
        content
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch sizing {
        case .fixed(let size, let mode) where mode == .fit:
            image(placeholderAspect: size.width / size.height)
                .aspectRatio(contentMode: .fit)
                .clipShape(shape)
                .frame(width: size.width, height: size.height)
        case .fixed(let size, _):
            Color.clear
                .frame(width: size.width, height: size.height)
                .overlay { image(placeholderAspect: size.width / size.height).aspectRatio(contentMode: .fill) }
                .clipShape(shape)
                .contentShape(shape)
        case .width(_, let aspectRatio?):
            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay { image(placeholderAspect: aspectRatio).aspectRatio(contentMode: .fill) }
                .clipShape(shape)
                .contentShape(shape)
        case .width(_, nil):
            image(placeholderAspect: Tokens.Aspect.cover)
                .aspectRatio(contentMode: .fit)
                .clipShape(shape)
        }
    }

    /// The placeholder takes the box's aspect ratio so the outer `aspectRatio(contentMode:)`, which
    /// measures whichever of image or placeholder is showing, sizes it to exactly the box.
    private func image(placeholderAspect: CGFloat) -> KFImage {
        KFImage(url)
            .setProcessor(processor)
            .cacheOriginalImage()
            .cacheMemoryOnly()
            .scaleFactor(displayScale)
            .cancelOnDisappear(true)
            .fade(duration: Tokens.Duration.imageFade)
            .placeholder { [url, cornerRadius] in
                ImagePlaceholder(
                    aspectRatio: placeholderAspect, cornerRadius: cornerRadius,
                    style: url == nil ? .plain : .activity
                )
            }
            .onFailureView { [cornerRadius] in
                ImagePlaceholder(aspectRatio: placeholderAspect, cornerRadius: cornerRadius, style: .failure)
            }
            .resizable()
    }

    private var processor: DownsampleProcessor {
        switch sizing {
        case .fixed(let size, let mode):
            DownsampleProcessor(
                pixelSize: CGSize(width: size.width * displayScale, height: size.height * displayScale),
                mode: mode == .fill ? .fill : .fit,
                webtoon: webtoon
            )
        case .width(let width, let aspectRatio):
            DownsampleProcessor(
                pixelSize: CGSize(
                    width: width * displayScale,
                    height: aspectRatio.map { width / $0 * displayScale } ?? 0
                ),
                mode: .fill,
                webtoon: webtoon
            )
        }
    }
}

private struct RemoteImagePreview: View {
    private let cover = URL(string: "https://picsum.photos/id/237/500/700")
    private let webtoon = URL(string: "https://picsum.photos/id/1015/200/1200")

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.large) {
            HStack(spacing: Tokens.Spacing.medium) {
                RemoteImage(url: cover, size: Tokens.ImageSize.row)
                RemoteImage(url: cover, size: Tokens.ImageSize.row, contentMode: .fill)
                RemoteImage(url: webtoon, size: Tokens.ImageSize.row, cropsWebtoon: true)
                RemoteImage(url: nil, size: Tokens.ImageSize.row)
            }
            HStack(alignment: .top, spacing: Tokens.Spacing.medium) {
                RemoteImage(url: cover, width: 150, aspectRatio: 1)
                RemoteImage(url: webtoon, width: 150, cropsWebtoon: true)
            }
        }
    }
}

#Preview {
    SchemePreview { RemoteImagePreview() }
}
