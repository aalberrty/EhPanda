import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Cover, title, uploader, category, favourite control and the READ button.
struct DetailHeaderSection: View {
    let model: GalleryDetailModel

    @Environment(SettingsStore.self) private var settings
    @Environment(StackRouter.self) private var stack: StackRouter?
    @State private var showsFullTitle = false
    @State private var searchCount = 0

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.medium) {
            RemoteImage(url: model.gallery.coverURL ?? model.detail?.coverURL, size: Tokens.ImageSize.header)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
                title
                uploader
                Spacer(minLength: Tokens.Spacing.small)
                HStack(spacing: Tokens.Spacing.small) {
                    CategoryLabel(
                        model.gallery.category.localizedName,
                        color: model.gallery.category.color(for: settings.galleryHost),
                        font: .subheadline
                    )
                    Spacer(minLength: 0)
                    FavoriteControl(model: model)
                    readButton
                }
                .minimumScaleFactor(0.5)
            }
            .frame(minHeight: Tokens.ImageSize.header.height)
        }
    }

    private var title: some View {
        Button {
            withAnimation { showsFullTitle.toggle() }
        } label: {
            Text(model.title(prefersJapanese: settings.displaysJapaneseTitle))
                .font(.title3.bold())
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
                .lineLimit(showsFullTitle ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: showsFullTitle)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var uploader: some View {
        if let uploader = model.uploader {
            Button(uploader) {
                searchCount += 1
                stack?.push(.search(keyword: DetailSearchKeyword.uploader(uploader)))
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: searchCount)
        }
    }

    private var readButton: some View {
        Button {
            model.openReader()
        } label: {
            Text(L10n.Localizable.DetailView.Button.read)
                .font(.headline)
                .textCase(.uppercase)
                .lineLimit(1)
                .padding(.horizontal, Tokens.Spacing.xxSmall)
        }
        .glassProminentButtonStyle()
        .buttonBorderShape(.capsule)
    }
}

/// A filled heart that removes the gallery from favourites, or an outlined heart whose menu adds
/// it to one of the ten folders. Disabled when logged out.
private struct FavoriteControl: View {
    let model: GalleryDetailModel

    @Environment(UserStore.self) private var userStore

    var body: some View {
        Group {
            if model.detail?.isFavorited == true {
                Button(action: model.unfavorite) {
                    Image(systemName: "heart.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(L10n.Localizable.GalleryInfosView.Title.favorited)
            } else {
                Menu {
                    ForEach(0..<10, id: \.self) { index in
                        Button(folderName(index)) { model.favorite(category: index) }
                    }
                } label: {
                    Image(systemName: "heart")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(L10n.Localizable.TabItem.Title.favorites)
            }
        }
        .imageScale(.large)
        .glassButtonStyle()
        .buttonBorderShape(.circle)
        .disabled(!model.isLoggedIn)
    }

    private func folderName(_ index: Int) -> String {
        userStore.customFavoriteCategoryName(index: index)
            ?? L10n.Localizable.Struct.User.FavoriteCategory.default("\(index)")
    }
}

/// The page's backdrop: the cover glow on iOS 26, the blurred cover on iOS 18.
struct DetailBackdrop: View {
    let model: GalleryDetailModel

    var body: some View {
        CoverGlow(gallery: model.gallery, coverURL: model.gallery.coverURL ?? model.detail?.coverURL, style: .page)
    }
}
