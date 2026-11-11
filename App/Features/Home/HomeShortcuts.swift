import EhFeatures
import SwiftUI

/// Tiles for the lists that have no section of their own (legacy `MiscGridSection`).
struct HomeShortcuts: View {
    let open: (GalleryListKind) -> Void

    private static let kinds: [GalleryListKind] = [.popular, .watched, .history]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Tokens.Spacing.medium) {
                ForEach(Self.kinds, id: \.self) { kind in
                    Button { open(kind) } label: {
                        ShortcutTile(title: kind.shortcutTitle, systemImage: kind.shortcutSymbol)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, Tokens.Spacing.large, for: .scrollContent)
    }
}

private struct ShortcutTile: View {
    let title: String
    let systemImage: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Spacing.large, style: .continuous)
        Text(title)
            .font(.title2.bold())
            .lineLimit(1)
            .frame(minWidth: 100, alignment: .leading)
            .padding(.trailing, 56)
            .padding(.vertical, Tokens.Spacing.xxLarge)
            .padding(.leading, Tokens.Spacing.xxLarge)
            .background(alignment: .bottomTrailing) {
                // Legacy let the symbol overflow the tile's corner.
                Image(systemName: systemImage)
                    .font(.system(size: 50, weight: .light))
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .offset(x: 10, y: 14)
                    .accessibilityHidden(true)
            }
            .background(.fill.tertiary, in: shape)
            .clipShape(shape)
            .contentShape(shape)
    }
}

private extension GalleryListKind {
    var shortcutTitle: String {
        switch self {
        case .popular: L10n.Localizable.Enum.HomeMiscGridType.Title.popular
        case .watched: L10n.Localizable.Enum.HomeMiscGridType.Title.watched
        case .history: L10n.Localizable.Enum.HomeMiscGridType.Title.history
        case .frontpage: L10n.Localizable.HomeView.Section.Title.frontpage
        case .toplists: L10n.Localizable.HomeView.Section.Title.toplists
        }
    }

    var shortcutSymbol: String {
        switch self {
        case .popular: "flame"
        case .watched: "tag.circle"
        case .history: "clock.arrow.circlepath"
        case .frontpage: "newspaper"
        case .toplists: "list.number"
        }
    }
}

#Preview {
    HomeShortcuts(open: { _ in })
}
