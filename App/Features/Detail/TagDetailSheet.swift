import EhFeatures
import EhModels
import SwiftUI

/// A translated tag's description, images and links.
struct TagDetailSheet: View {
    let detail: TagDetail

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xLarge) {
                    Text(detail.description)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    SubSection(title: L10n.Localizable.TagDetailView.Section.Title.images, showsAll: false) {
                        images
                    }
                    SubSection(title: L10n.Localizable.TagDetailView.Section.Title.links, showsAll: false) {
                        links
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(detail.title.removingEmojiPresentation)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var images: some View {
        if detail.imageURLs.isEmpty {
            EmptyStateView()
        } else {
            let range = Tokens.ImageSize.previewWidths(for: sizeClass)
            let width = (range.lowerBound + range.upperBound) / 2
            ScrollView(.horizontal) {
                LazyHStack(spacing: Tokens.Spacing.small) {
                    ForEach(detail.imageURLs, id: \.self) { url in
                        RemoteImage(url: url, size: CGSize(width: width, height: width / Tokens.Aspect.preview))
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Tokens.Spacing.large, for: .scrollContent)
        }
    }

    /// Links open in the system browser.
    @ViewBuilder
    private var links: some View {
        if detail.links.isEmpty {
            EmptyStateView()
        } else {
            VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                ForEach(detail.links, id: \.self) { url in
                    Link(destination: url) {
                        Text(url.absoluteString)
                            .font(.callout.bold())
                            .multilineTextAlignment(.leading)
                    }
                    .tint(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }
}
