import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Galleries as list rows or as a grid of large covers, following `SettingsStore.listDisplayMode`
/// (legacy `GenericList` content). Tapping a gallery pushes its detail on the current stack; a
/// long press offers Read, which opens the reader over the list, and Share.
///
/// Both modes are lazy. `footer` is the last row of the list, or the footer of the grid, and is
/// only created when it scrolls into view, so a task on it starts when the end is reached.
struct GalleryCollection<Footer: View>: View {
    private let galleries: [Gallery]
    private let footer: Footer

    @Environment(SettingsStore.self) private var settings
    @State private var model = GalleryCollectionModel()

    init(galleries: [Gallery], @ViewBuilder footer: () -> Footer) {
        self.galleries = galleries
        self.footer = footer()
    }

    var body: some View {
        Group {
            switch settings.listDisplayMode {
            case .detail:
                GalleryRows(galleries: galleries, footer: footer, model: model)
            case .thumbnail:
                GalleryGrid(galleries: galleries, footer: footer, model: model)
            }
        }
        .fullScreenCover(item: $model.readingGallery) { gallery in
            ReaderScreen(gallery: gallery)
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
    let model: GalleryCollectionModel

    @Environment(StackRouter.self) private var stack

    var body: some View {
        List {
            ForEach(galleries) { gallery in
                Button {
                    stack.push(.detail(gallery))
                } label: {
                    GalleryDetailRow(gallery: gallery)
                }
                .foregroundStyle(.textPrimary)
                // The row already shows everything the peek would, so the system lifts the row.
                .contextMenu {
                    GalleryMenuItems(gallery: gallery) { model.read(gallery) }
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(.hairline)
            }
            footer
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}

private struct GalleryGrid<Footer: View>: View {
    let galleries: [Gallery]
    let footer: Footer
    let model: GalleryCollectionModel

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The grid's own width, measured once for the whole grid rather than per cell.
    @State private var width: CGFloat = 0

    var body: some View {
        let metrics = GalleryGridMetrics(
            containerWidth: width, sizeClass: sizeClass, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
        ScrollView {
            LazyVGrid(columns: metrics.columns, spacing: GalleryGridMetrics.rowSpacing) {
                // Cells wait for the width, so covers are requested at their final size. The
                // grid itself stays, so the scroll view has content to take the width from.
                if width > 0 {
                    Section {
                        ForEach(galleries) { gallery in
                            GalleryGridItem(gallery: gallery, metrics: metrics, model: model)
                        }
                    } footer: {
                        footer
                    }
                }
            }
            .padding(.horizontal, GalleryGridMetrics.margin)
            .padding(.vertical, Tokens.Spacing.small)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

private struct GalleryGridItem: View {
    let gallery: Gallery
    let metrics: GalleryGridMetrics
    let model: GalleryCollectionModel

    @Environment(StackRouter.self) private var stack
    // Only handed on to the peek; reading the stores observes none of their properties.
    @Environment(SettingsStore.self) private var settings
    @Environment(TagTranslationService.self) private var tagTranslations: TagTranslationService?

    var body: some View {
        Button {
            stack.push(.detail(gallery))
        } label: {
            GalleryThumbnailCell(gallery: gallery, coverWidth: metrics.coverDecodeWidth)
        }
        .buttonStyle(.plain)
        .contextMenu {
            GalleryMenuItems(gallery: gallery) { model.read(gallery) }
        } preview: {
            // The preview is hosted outside this hierarchy and does not inherit its environment.
            GalleryPeek(gallery: gallery, coverDecodeWidth: metrics.coverDecodeWidth, width: metrics.peekWidth)
                .environment(settings)
                .environment(tagTranslations)
        }
    }
}

/// Columns of the cover grid: two across in compact width (the design's two large covers), as
/// many as fit in regular width (legacy iPad: four in portrait, five in landscape).
///
/// At accessibility sizes two columns cut a cell's category and page count to a letter, so
/// compact width shows one and regular width's columns are twice as wide.
struct GalleryGridMetrics: Equatable {
    static let margin: CGFloat = Tokens.Spacing.large
    static let columnSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = Tokens.Spacing.xLarge
    /// The narrowest column in regular width.
    static let minimumRegularColumnWidth: CGFloat = 180
    /// The widest the long-press peek gets, on iPad.
    static let maximumPeekWidth: CGFloat = 440

    let columnCount: Int
    let columnWidth: CGFloat
    let peekWidth: CGFloat

    init(containerWidth: CGFloat, sizeClass: UserInterfaceSizeClass?, isAccessibilitySize: Bool) {
        let available = max(containerWidth - Self.margin * 2, 0)
        let minimumColumnWidth = Self.minimumRegularColumnWidth * (isAccessibilitySize ? 2 : 1)
        let minimumCount = isAccessibilitySize ? 1 : 2
        let count = if sizeClass == .regular {
            max(minimumCount, Int((available + Self.columnSpacing) / (minimumColumnWidth + Self.columnSpacing)))
        } else {
            minimumCount
        }
        columnCount = count
        columnWidth = max((available - Self.columnSpacing * CGFloat(count - 1)) / CGFloat(count), 0)
        // The card spans the screen with a small margin, as drawn; capped on iPad.
        peekWidth = min(max(containerWidth - Tokens.Spacing.large, 0), Self.maximumPeekWidth)
    }

    var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Self.columnSpacing, alignment: .top), count: columnCount)
    }

    /// Covers are decoded at the column width, rounded up to whole points.
    var coverDecodeWidth: CGFloat { columnWidth.rounded(.up) }
}
