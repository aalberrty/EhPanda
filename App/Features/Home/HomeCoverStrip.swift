import EhFeatures
import EhModels
import SwiftUI

/// Frontpage covers in columns of two (legacy `CoverWallSection`). Placeholder columns stand in
/// while the first load is running.
struct HomeCoverStrip: View {
    let columns: [CoverColumn]
    let showsPlaceholders: Bool
    let open: (Gallery) -> Void

    private static let placeholderCount = 6
    private static let spacing = Tokens.Spacing.xLarge

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Self.spacing) {
                if showsPlaceholders {
                    ForEach(0..<Self.placeholderCount, id: \.self) { _ in
                        VStack(spacing: Self.spacing) {
                            placeholder
                            placeholder
                        }
                    }
                } else {
                    ForEach(columns) { column in
                        VStack(spacing: Self.spacing) {
                            cover(column.top)
                            cover(column.bottom)
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, Tokens.Spacing.large, for: .scrollContent)
        .frame(height: Tokens.ImageSize.row.height * 2 + Self.spacing)
    }

    private func cover(_ gallery: Gallery) -> some View {
        Button { open(gallery) } label: {
            RemoteImage(url: gallery.coverURL, size: Tokens.ImageSize.row, contentMode: .fill, cropsWebtoon: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(gallery.title)
    }

    private var placeholder: some View {
        ImagePlaceholder(style: .shimmer)
            .frame(width: Tokens.ImageSize.row.width, height: Tokens.ImageSize.row.height)
    }
}

#Preview {
    VStack {
        HomeCoverStrip(columns: [], showsPlaceholders: true, open: { _ in })
    }
}
