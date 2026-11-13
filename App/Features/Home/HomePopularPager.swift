import Dependencies
import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Popular as a pager of covers: one per page, its neighbours smaller and dimmed at both edges,
/// over a quiet glow of the current cover's colours. Below it a "Popular ›" link to the full
/// list, then the current gallery's title, category, pages and rating (E-Home).
///
/// It opens on the second gallery, as legacy's carousel did. The glow is the one `CoverGlow`
/// behind the whole pager, never one per page; it is static and scrolls away with the pager.
struct HomePopularPager: View {
    let galleries: [Gallery]
    let open: (Gallery) -> Void
    let openPopular: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var currentID: String?

    private var current: Gallery? {
        galleries.first { $0.id == currentID } ?? galleries.first
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.xSmall) {
            PopularPages(
                galleries: galleries, coverSize: coverSize, currentID: $currentID, open: open
            )
            if let current {
                PopularCaption(
                    gallery: current,
                    title: HomeSections.cardTitle(of: current, isCompact: sizeClass != .regular),
                    open: { open(current) },
                    openPopular: openPopular
                )
            }
        }
        .background {
            if let current {
                // Reaches up under the bars to the top of the screen and fades out a little
                // below the caption, as drawn (E-Home: the top 620 pt).
                CoverGlow(gallery: current, style: .quiet)
                    .padding(.top, -Self.glowAbove)
                    .padding(.bottom, -Self.glowBelow)
            }
        }
        // Only a new set of galleries moves back to the second one; refreshed fields of the
        // same galleries keep the page the user swiped to. The initial call also runs again
        // when the screen reappears after a pushed one, which must not move the pager either.
        .onChange(of: galleries.map(\.id), initial: true) { oldIDs, ids in
            currentID = HomeSections.pagerPage(current: currentID, oldIDs: oldIDs, ids: ids)
        }
    }

    /// E-Home's 216 × 297 pt cover on iPhone; larger on iPad.
    private var coverSize: CGSize {
        let width: CGFloat = sizeClass == .regular ? 264 : 216
        return CGSize(width: width, height: (width / Tokens.Aspect.cover).rounded())
    }

    /// Enough to pass the status bar, navigation bar and large title, with room for a pull.
    private static let glowAbove: CGFloat = 300
    private static let glowBelow: CGFloat = 120
}

/// The paging row of covers, centred by margins measured from the pager's own width.
private struct PopularPages: View {
    let galleries: [Gallery]
    let coverSize: CGSize
    @Binding var currentID: String?
    let open: (Gallery) -> Void

    @State private var width: CGFloat = 0

    var body: some View {
        let spacing = NeighbourEffect.spacing
        let pageWidth = coverSize.width + spacing
        ScrollView(.horizontal) {
            LazyHStack(spacing: spacing) {
                ForEach(galleries) { gallery in
                    PopularPage(gallery: gallery, coverSize: coverSize, pageWidth: pageWidth, open: open)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .scrollPosition(id: $currentID, anchor: .center)
        .contentMargins(.horizontal, max((width - coverSize.width) / 2, 0), for: .scrollContent)
        // The current cover's shadow reaches below the row.
        .scrollClipDisabled()
        .frame(height: coverSize.height)
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { width = $0 }
    }
}

private struct PopularPage: View {
    let gallery: Gallery
    let coverSize: CGSize
    let pageWidth: CGFloat
    let open: (Gallery) -> Void

    @Environment(CoverPaletteStore.self) private var palettes

    var body: some View {
        Button { open(gallery) } label: {
            PopularCover(url: gallery.coverURL, size: coverSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(gallery.title)
        .modifier(NeighbourEffect(pageWidth: pageWidth))
        // Ready before the page turns, so the glow fades straight to its colours.
        .task(id: gallery.id) { await palettes.load(gallery) }
    }
}

/// The page closest to the centre is full size; the others shrink toward it and dim. It follows
/// the scroll offset in a visual effect, so paging re-evaluates no view bodies.
private struct NeighbourEffect: ViewModifier {
    let pageWidth: CGFloat

    func body(content: Content) -> some View {
        content.visualEffect { [pageWidth] effect, proxy in
            Self.apply(to: effect, proxy: proxy, pageWidth: pageWidth)
        }
    }

    nonisolated private static func apply(
        to effect: EmptyVisualEffect, proxy: GeometryProxy, pageWidth: CGFloat
    ) -> some VisualEffect {
        let offset: CGFloat = offsetFromCentre(proxy, pageWidth: pageWidth)
        let progress: CGFloat = min(abs(offset), 1)
        let scale: CGFloat = 1 - progress * (1 - neighbourScale)
        let opacity: Double = 1 - progress * (1 - neighbourOpacity)
        let anchor: UnitPoint = offset < 0 ? .trailing : .leading
        return effect.scaleEffect(scale, anchor: anchor).opacity(opacity)
    }

    /// How far the view's centre is from the pager's, in pages: 0 centred, ±1 a neighbour at rest.
    nonisolated private static func offsetFromCentre(_ proxy: GeometryProxy, pageWidth: CGFloat) -> CGFloat {
        guard pageWidth > 0, let bounds = proxy.bounds(of: .scrollView(axis: .horizontal)) else { return 0 }
        let frame: CGRect = proxy.frame(in: .local)
        return (frame.midX - bounds.midX) / pageWidth
    }

    static let spacing: CGFloat = 14
    /// E-Home's neighbours: 184 pt beside the 216 pt page, at 55 %.
    nonisolated private static let neighbourScale: CGFloat = 184 / 216
    nonisolated private static let neighbourOpacity: CGFloat = 0.55
}

/// One cover of the pager, lifted off the glow by a soft shadow.
private struct PopularCover: View {
    let url: URL?
    let size: CGSize

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        RemoteImage(url: url, size: size, contentMode: .fill, cornerRadius: Self.cornerRadius, cropsWebtoon: true)
            .overlay { shape.strokeBorder(.coverEdge, lineWidth: 1) }
            // A shadow of a plain shape, not of the image, so it is drawn from the path.
            .background {
                shape
                    .fill(.ground)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.18), radius: 20, y: 18)
            }
    }

    private static let cornerRadius: CGFloat = 14
}

/// "Popular ›" and the current gallery's title and figures, centred under the pager.
private struct PopularCaption: View {
    let gallery: Gallery
    let title: String
    let open: () -> Void
    let openPopular: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.xxSmall) {
            Button(action: openPopular) {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    Text(L10n.Localizable.Enum.HomeMiscGridType.Title.popular)
                    Image(systemName: "chevron.forward")
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Tokens.Spacing.small)
                .frame(minHeight: 32)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button(action: open) {
                VStack(spacing: Tokens.Spacing.xSmall) {
                    // Two lines kept free, so a shorter title does not move the page below.
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2, reservesSpace: true)
                        .contentTransition(.opacity)
                    PopularFigures(gallery: gallery)
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Spacing.xxLarge)
        .animation(.easeInOut(duration: 0.25), value: gallery.id)
    }
}

/// Category · pages · rating, as one line of secondary text.
private struct PopularFigures: View {
    let gallery: Gallery

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        let rating = RatingStars.halfRounded(Double(gallery.rating))
        let category = gallery.category.localizedName
        let pages = L10n.Localizable.Common.Value.pages("\(gallery.pageCount)")
        HStack(spacing: 6) {
            CategoryLabel(category, color: gallery.color(for: settings.galleryHost))
            Text(verbatim: "·")
            Text(pages)
            Text(verbatim: "·")
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .imageScale(.small)
                    .foregroundStyle(.rating)
                Text(rating, format: .number.precision(.fractionLength(1)))
            }
        }
        .font(.footnote)
        .foregroundStyle(.textSecondary)
        .lineLimit(1)
        .contentTransition(.opacity)
        // One phrase for VoiceOver, without the separators: "Doujinshi, 64 pages, Average rating, 4.5/5".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([
            category, pages, L10n.Localizable.GalleryInfosView.Title.averageRating,
            RatingStars.accessibilityValue(for: rating)
        ].joined(separator: ", "))
    }
}

private struct HomePopularPagerPreview: View {
    @Dependency(\.settings) private var settings

    var body: some View {
        ScrollView {
            HomePopularPager(
                galleries: (0..<4).map { index in
                    Gallery(
                        gid: "\(index)", token: "", title: "Morning Light Sketchbook \(index)", rating: 4.5,
                        tags: [], category: .artistCG, uploader: nil, pageCount: 64, postedDate: .now,
                        coverURL: Gallery.preview.coverURL, galleryURL: nil
                    )
                },
                open: { _ in }, openPopular: {}
            )
            .padding(.top, 100)
        }
        .screenGround()
        .environment(settings)
        .environment(CoverPaletteStore())
    }
}

#Preview {
    HomePopularPagerPreview()
}
