import EhFeatures
import EhModels
import SwiftUI

/// Every page's preview in a lazy grid, loaded a preview page at a time as it scrolls into view.
struct PreviewsGridScreen: View {
    /// Handed to the reader for its title.
    private let detail: GalleryDetail?

    @State private var model: PreviewsModel

    @Environment(\.horizontalSizeClass) private var sizeClass

    init(gallery: Gallery, detail: GalleryDetail?, pageCount: Int, config: PreviewConfig?, previewURLs: [Int: URL]) {
        self.detail = detail
        _model = State(initialValue: PreviewsModel(
            gallery: gallery, pageCount: pageCount, config: config, previewURLs: previewURLs
        ))
    }

    var body: some View {
        let widths = Tokens.ImageSize.previewWidths(for: sizeClass)
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: widths.lowerBound, maximum: widths.upperBound), spacing: 10)],
                spacing: Tokens.Spacing.medium
            ) {
                ForEach(1..<(model.pageCount + 1), id: \.self) { index in
                    Button {
                        model.select(index)
                    } label: {
                        PreviewGridCell(
                            index: index, thumbnail: model.preview(at: index),
                            failed: model.hasFailed(at: index), width: widths.upperBound,
                            isRegular: sizeClass == .regular
                        )
                    }
                    .buttonStyle(.plain)
                    .onAppear { model.thumbnailAppeared(index) }
                    .onDisappear { model.thumbnailDisappeared(index) }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .screenGround()
        .navigationTitle(L10n.Localizable.PreviewsView.Title.previews)
        .task { await model.load() }
        .fullScreenCover(item: $model.readerDestination) { destination in
            if case .reader(let page) = destination {
                ReaderScreen(gallery: model.gallery, initialPage: page, detail: detail)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.readerDestination) { _, destination in
            destination != nil
        }
    }
}

private struct PreviewGridCell: View, Equatable {
    let index: Int
    let thumbnail: PreviewThumbnail?
    let failed: Bool
    let width: CGFloat
    let isRegular: Bool

    var body: some View {
        VStack(spacing: Tokens.Spacing.xSmall) {
            PreviewThumbnailView(thumbnail: thumbnail, width: width, failed: failed)
            Text(index, format: .number)
                .font(isRegular ? .callout : .caption)
                .foregroundStyle(.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(failed ? L10n.Localizable.ErrorView.Button.retry : "")
    }
}
