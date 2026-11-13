import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The cover as the page's hero with Read set into its lower edge (tapping the cover reads
/// too), then the title, the uploader and the category (E-Detail).
struct DetailHeroSection: View {
    let model: GalleryDetailModel

    @Environment(SettingsStore.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 0) {
            // Read overlaps the cover by half its height.
            VStack(spacing: -Self.readOverlap) {
                HeroCover(url: model.gallery.coverURL ?? model.detail?.coverURL, width: coverWidth) {
                    model.openReader()
                }
                ReadButton { model.openReader() }
            }
            HeroTitle(text: model.title(prefersJapanese: settings.displaysJapaneseTitle))
                .padding(.top, Tokens.Spacing.medium)
                .padding(.horizontal, Tokens.Spacing.xLarge + Tokens.Spacing.xSmall)
            HeroMeta(
                uploader: model.uploader,
                category: model.gallery.category.localizedName,
                categoryColor: model.gallery.category.color(for: settings.galleryHost)
            )
            .padding(.top, Tokens.Spacing.xxSmall)
            .padding(.horizontal, DetailMetrics.pageMargin)
        }
        .frame(maxWidth: .infinity)
    }

    /// E-Detail draws a 204 pt cover on a phone; a regular width gets a larger one.
    private var coverWidth: CGFloat {
        sizeClass == .regular ? 260 : 204
    }

    private static let readOverlap: CGFloat = 25
}

private struct HeroCover: View {
    let url: URL?
    let width: CGFloat
    let read: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        Button(action: read) {
            RemoteImage(
                url: url, size: CGSize(width: width, height: width / Tokens.Aspect.cover),
                contentMode: .fill, cornerRadius: Self.cornerRadius, cropsWebtoon: true
            )
            .overlay { shape.strokeBorder(.coverEdge, lineWidth: 1) }
            .compositingGroup()
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.22), radius: 24, y: 20)
        }
        .buttonStyle(.plain)
        // Read is the accessible way in; the cover only repeats it for touch.
        .accessibilityHidden(true)
    }

    private static let cornerRadius: CGFloat = 14
}

private struct ReadButton: View {
    let read: () -> Void

    var body: some View {
        Button(action: read) {
            Text(L10n.Localizable.DetailView.Button.read)
                .font(.headline)
                .lineLimit(1)
                .padding(.horizontal, Tokens.Spacing.xxLarge)
                .padding(.vertical, Tokens.Spacing.xSmall)
        }
        .glassProminentButtonStyle()
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        // A ring of the ground lifts the button off the cover it overlaps.
        .background {
            Capsule()
                .fill(.ground.opacity(0.45))
                .padding(-Tokens.Spacing.xSmall)
        }
    }
}

/// The gallery title, three lines until tapped. Gallery titles keep the default font design.
private struct HeroTitle: View {
    let text: String

    @State private var showsFullTitle = false

    var body: some View {
        Button {
            withAnimation { showsFullTitle.toggle() }
        } label: {
            Text(text)
                .font(.title2.bold())
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(showsFullTitle ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: showsFullTitle)
        .accessibilityAddTraits(.isHeader)
    }
}

/// "uploader · ● Category"; tapping the uploader searches for their galleries.
private struct HeroMeta: View {
    let uploader: String?
    let category: String
    let categoryColor: Color

    @Environment(StackRouter.self) private var stack: StackRouter?
    @State private var searchCount = 0

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            if let uploader {
                Button(uploader) {
                    searchCount += 1
                    stack?.push(.search(keyword: DetailSearchKeyword.uploader(uploader)))
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                // A 44 pt target on a one-line row.
                .padding(.vertical, Tokens.Spacing.medium)
                .contentShape(.rect)
                .padding(.vertical, -Tokens.Spacing.medium)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: searchCount)
                Text(verbatim: "·")
                    .font(.footnote)
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }
            CategoryLabel(category, color: categoryColor)
                .layoutPriority(1)
        }
    }
}
