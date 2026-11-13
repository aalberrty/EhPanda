import EhFeatures
import EhModels
import SwiftUI

/// Frontpage as a wall of covers with their titles: three across on iPhone, six on iPad, two
/// rows (E-Home). Placeholders stand in while the first load runs. Plain cells, no glow or
/// glass, so the wall scrolls cheaply.
struct HomeFrontpageWall: View {
    let galleries: [Gallery]
    let showsPlaceholders: Bool
    let open: (Gallery) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let columnCount = sizeClass == .regular ? 6 : 3
        let decodeWidth: CGFloat = sizeClass == .regular ? 220 : 130
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: Tokens.Spacing.medium, alignment: .top), count: columnCount
            ),
            spacing: Tokens.Spacing.large
        ) {
            if showsPlaceholders {
                ForEach(0..<columnCount * HomeSections.frontpageWallRows, id: \.self) { _ in
                    WallPlaceholder()
                }
            } else {
                ForEach(HomeSections.frontpageWall(from: galleries, columns: columnCount)) { gallery in
                    Button { open(gallery) } label: {
                        WallCell(
                            title: HomeSections.shortTitle(of: gallery), coverURL: gallery.coverURL,
                            decodeWidth: decodeWidth
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.large)
    }
}

/// A cover and up to two lines of its title. Two lines are always kept, so the rows line up.
private struct WallCell: View {
    let title: String
    let coverURL: URL?
    /// The widest the cover can get at this size class: the image is decoded at this width.
    let decodeWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: coverURL, width: decodeWidth, aspectRatio: Tokens.Aspect.cover, cropsWebtoon: true)
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.image, style: .continuous)
                        .strokeBorder(.coverEdge, lineWidth: 1)
                }
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2, reservesSpace: true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct WallPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ImagePlaceholder(style: .shimmer)
            // The height of the two title lines a loaded cell keeps, so nothing moves on load.
            Text(verbatim: " ")
                .font(.caption.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.chipFill)
                        .frame(height: 10)
                        .padding(.trailing, Tokens.Spacing.large)
                        .padding(.top, 2)
                }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    SchemePreview {
        VStack(spacing: Tokens.Spacing.xLarge) {
            HomeFrontpageWall(galleries: [], showsPlaceholders: true, open: { _ in })
            HomeFrontpageWall(
                galleries: (0..<6).map { index in
                    Gallery(
                        gid: "\(index)", token: "", title: "[Circle] Cosmic Drift Concept Art \(index)", rating: 4,
                        tags: [], category: .artistCG, pageCount: 24, postedDate: .now,
                        coverURL: Gallery.preview.coverURL, galleryURL: nil
                    )
                },
                showsPlaceholders: false, open: { _ in }
            )
        }
    }
}
