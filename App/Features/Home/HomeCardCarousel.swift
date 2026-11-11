import EhFeatures
import EhModels
import SwiftUI

/// The Popular cards: a paging carousel that opens on the second card, with neighbours peeking
/// in at both edges (legacy `CardSlideSection` on SwiftUIPager).
struct HomeCardCarousel: View {
    let cards: [Gallery]
    /// Whether the page around the carousel is scrolling.
    var pageScrolling = PageScrollState()
    let open: (Gallery) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var palettes = CardPaletteStore()
    @State private var currentID: String?
    /// Whether any of the carousel is inside the page's visible area, and the screen is not
    /// covered by a pushed one. The current card's backdrop only drifts while it can be seen.
    @State private var isOnScreen = false
    @State private var isOnPage = true
    @State private var areCardsScrolling = false

    private var animatesCurrentCard: Bool {
        isOnScreen && isOnPage && !pageScrolling.isScrolling && !areCardsScrolling
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Tokens.Spacing.medium) {
                ForEach(cards) { gallery in
                    Button { open(gallery) } label: {
                        HomeCard(
                            gallery: gallery,
                            title: HomeSections.cardTitle(of: gallery, isCompact: sizeClass != .regular),
                            palette: palettes.palettes[gallery.id],
                            isAnimated: animatesCurrentCard && gallery.id == currentID
                        )
                    }
                    .buttonStyle(.plain)
                    // The scroll view's content margins are already taken out of the container.
                    .containerRelativeFrame(.horizontal)
                    .task(id: gallery.id) { await palettes.loadPalette(for: gallery) }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $currentID, anchor: .center)
        .contentMargins(.horizontal, sideMargin, for: .scrollContent)
        .frame(height: Tokens.ImageSize.cardHeight)
        .onScrollPhaseChange { _, phase in areCardsScrolling = phase.isScrolling }
        // Reported against the page's vertical scroll view.
        .onScrollVisibilityChange(threshold: 0.01) { isOnPage = $0 }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        // Only a new set of cards moves back to the first one; refreshed fields of the same
        // galleries keep the card the user scrolled to.
        .onChange(of: cards.map(\.id), initial: true) { _, ids in
            currentID = HomeSections.initialCardIndex(count: ids.count).map { ids[$0] }
        }
    }

    /// Legacy cards were 80% of the window wide; these margins give about the same.
    private var sideMargin: CGFloat {
        sizeClass == .regular ? 96 : 36
    }
}

/// Whether a scroll view is scrolling, for a child that pauses work meanwhile.
@Observable
final class PageScrollState {
    var isScrolling = false
}

/// One Popular card: cover, title and rating over a gradient of the cover's colours.
private struct HomeCard: View {
    let gallery: Gallery
    let title: String
    let palette: CardPalette?
    let isAnimated: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Spacing.xLarge, style: .continuous)
        HStack(alignment: .top, spacing: Tokens.Spacing.large) {
            RemoteImage(
                url: gallery.coverURL, size: Tokens.ImageSize.header, contentMode: .fill, cropsWebtoon: true
            )
            VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                Text(title)
                    .font(.title3.bold())
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                RatingStars(rating: Double(gallery.rating))
                    .foregroundStyle(.yellow)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Tokens.Spacing.xLarge)
        .frame(height: Tokens.ImageSize.cardHeight)
        // Legacy animated only the current card, and only in dark mode.
        .background { CardBackground(palette: palette, isAnimated: isAnimated && colorScheme == .dark) }
        .clipShape(shape)
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HomeCardCarousel(cards: [.preview], open: { _ in })
}
