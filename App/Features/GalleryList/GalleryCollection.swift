import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Galleries as list rows or as a grid of cards, following `SettingsStore.listDisplayMode`
/// (legacy `GenericList` content). Tapping a gallery pushes its detail on the current stack.
///
/// Both modes are lazy. `footer` is the last row of the list, or the footer of the grid, and is
/// only created when it scrolls into view, so a task on it starts when the end is reached.
struct GalleryCollection<Footer: View>: View {
    private let galleries: [Gallery]
    private let footer: Footer

    @Environment(SettingsStore.self) private var settings

    init(galleries: [Gallery], @ViewBuilder footer: () -> Footer) {
        self.galleries = galleries
        self.footer = footer()
    }

    var body: some View {
        switch settings.listDisplayMode {
        case .detail:
            GalleryRows(galleries: galleries, footer: footer)
        case .thumbnail:
            GalleryGrid(galleries: galleries, footer: footer)
        }
    }
}

extension GalleryCollection where Footer == EmptyView {
    init(galleries: [Gallery]) {
        self.init(galleries: galleries) { EmptyView() }
    }
}

private struct GalleryRows<Footer: View>: View {
    let galleries: [Gallery]
    let footer: Footer

    @Environment(StackRouter.self) private var stack

    var body: some View {
        List {
            ForEach(galleries) { gallery in
                Button {
                    stack.push(.detail(gallery))
                } label: {
                    GalleryDetailRow(gallery: gallery)
                }
                .foregroundStyle(.primary)
            }
            footer
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

/// Legacy grid spacing.
private let gridSpacing: CGFloat = 15

private struct GalleryGrid<Footer: View>: View {
    let galleries: [Gallery]
    let footer: Footer

    @Environment(StackRouter.self) private var stack
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Two columns in compact width (legacy iPhone); as many as fit in regular width
    /// (legacy iPad: four in portrait, five in landscape).
    private var columns: [GridItem] {
        if sizeClass == .regular {
            [GridItem(.adaptive(minimum: 180, maximum: GalleryThumbnailCell.maximumWidth), spacing: gridSpacing)]
        } else {
            Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 2)
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                Section {
                    ForEach(galleries) { gallery in
                        Button {
                            stack.push(.detail(gallery))
                        } label: {
                            GalleryThumbnailCell(gallery: gallery)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    footer
                }
            }
            .padding(.horizontal, Tokens.Spacing.large)
            .padding(.vertical, Tokens.Spacing.small)
        }
    }
}
