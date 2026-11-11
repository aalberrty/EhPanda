import Kingfisher
import SwiftUI

/// One page preview cut out of a sprite sheet (the site packs up to 20 previews into one image).
///
/// Every thumbnail of a sheet loads the same URL: Kingfisher merges the concurrent downloads,
/// keeps the sheet on disk once, and caches each crop under its own processor key (see
/// ``SpriteCropProcessor``). The view fills the proposed width at `aspectRatio` and fits the crop
/// inside it with rounded corners, as legacy previews did. For previews that are standalone
/// images, use ``RemoteImage`` instead.
struct SpriteThumbnail: View {
    private let sheetURL: URL?
    private let cropRect: CGRect
    private let aspectRatio: CGFloat
    private let cornerRadius: CGFloat

    /// - Parameters:
    ///   - sheetURL: The sprite sheet, without any crop parameters.
    ///   - cropRect: The thumbnail's rectangle in sheet pixels, origin at the top left.
    init(
        sheetURL: URL?, cropRect: CGRect,
        aspectRatio: CGFloat = Tokens.Aspect.preview, cornerRadius: CGFloat = Tokens.Radius.image
    ) {
        self.sheetURL = sheetURL
        self.cropRect = cropRect
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                KFImage(sheetURL)
                    .setProcessor(SpriteCropProcessor(rect: cropRect))
                    .cacheOriginalImage()
                    .cancelOnDisappear(true)
                    .fade(duration: Tokens.Duration.imageFade)
                    .placeholder { [sheetURL, aspectRatio, cornerRadius] in
                        ImagePlaceholder(
                            aspectRatio: aspectRatio, cornerRadius: cornerRadius,
                            style: sheetURL == nil ? .plain : .activity
                        )
                    }
                    .onFailureView { [aspectRatio, cornerRadius] in
                        ImagePlaceholder(aspectRatio: aspectRatio, cornerRadius: cornerRadius, style: .failure)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .accessibilityHidden(true)
    }
}

private struct SpriteThumbnailPreview: View {
    // Any wide image works for a preview: each cell shows a different 100 × 140 slice of it.
    private let sheet = URL(string: "https://picsum.photos/id/1043/1000/140")
    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 120))]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Tokens.Spacing.medium) {
            ForEach(0..<6) { index in
                SpriteThumbnail(sheetURL: sheet, cropRect: CGRect(x: index * 100, y: 0, width: 100, height: 140))
            }
            SpriteThumbnail(sheetURL: nil, cropRect: .zero)
        }
    }
}

#Preview {
    SchemePreview { SpriteThumbnailPreview() }
}
