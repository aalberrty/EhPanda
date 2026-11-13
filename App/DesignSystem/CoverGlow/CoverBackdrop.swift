import Kingfisher
import SwiftUI

/// The cover, blurred once by the image pipeline, fading into the background at the top of a
/// page: the detail page's backdrop in v3, and `CoverGlow`'s `.page` style on iOS 18.
///
/// The image is decoded at a few dozen pixels and blurred in Kingfisher's processing queue, so
/// scrolling over it costs nothing more than any static image.
struct CoverBackdrop: View {
    let url: URL?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        KFImage(url)
            .setProcessor(
                DownsampleProcessor(pixelSize: CGSize(width: 48, height: 66), mode: .fill)
                    .append(another: BlurImageProcessor(blurRadius: 6))
            )
            .cacheOriginalImage()
            .cacheMemoryOnly()
            .cancelOnDisappear(true)
            .fade(duration: Tokens.Duration.imageFade)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 420)
            .frame(maxWidth: .infinity)
            .clipped()
            .opacity(colorScheme == .dark ? 0.55 : 0.4)
            .mask {
                LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea(edges: .top)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}
