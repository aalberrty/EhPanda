import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The figures that are also the actions, on one glass bar (E-Detail): the average rating
/// gives a rating, the favourite count adds to or removes from favourites, and pages, language
/// and size lead to Gallery infos. Giving a rating opens the stars below the bar.
struct DetailFiguresSection: View {
    @Bindable var model: GalleryDetailModel

    var body: some View {
        if let detail = model.detail {
            GlassGroup(spacing: DetailMetrics.panelSpacing) {
                VStack(spacing: DetailMetrics.panelSpacing) {
                    FiguresBar(model: model, detail: detail)
                    if model.showsRatingControl {
                        RatingPanel(model: model)
                            .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
                    }
                }
            }
            .animation(.default, value: model.showsRatingControl)
        }
    }
}

private struct FiguresBar: View {
    let model: GalleryDetailModel
    let detail: GalleryDetail

    var body: some View {
        HStack(spacing: 0) {
            // The figures take what they need; pages, language and size get the rest.
            RatingFigure(model: model, rating: detail.rating)
                .fixedSize()
                .frame(minWidth: 88)
            FigureDivider()
            FavoriteFigure(model: model, count: detail.favoritedCount)
                .fixedSize()
                .frame(minWidth: 100)
            FigureDivider()
            InfosFigure(detail: detail) { model.destination = .galleryInfos }
        }
        .padding(.horizontal, Tokens.Spacing.xSmall + Tokens.Spacing.xxSmall)
        .frame(minHeight: 60)
        .glassSurface(in: .capsule, tone: .panel)
    }
}

private struct FigureDivider: View {
    var body: some View {
        Rectangle()
            .fill(.hairline)
            .frame(width: 1, height: 26)
            .accessibilityHidden(true)
    }
}

/// "★ 4.5": the average rating; tapping it shows the stars to give one. Logged out it only shows.
private struct RatingFigure: View {
    let model: GalleryDetailModel
    let rating: Float

    var body: some View {
        Button {
            withAnimation { model.toggleRatingControl() }
        } label: {
            FigureLabel(systemImage: "star.fill", symbolStyle: .rating) {
                Text(rating, format: .number.precision(.fractionLength(1...2)))
            }
        }
        .buttonStyle(PanelPressButtonStyle())
        .disabled(!model.isLoggedIn)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: model.showsRatingControl)
        .accessibilityLabel(L10n.Localizable.DetailView.ActionSection.Button.giveARating)
        .accessibilityValue(
            L10n.Localizable.GalleryInfosView.Title.averageRating + ", "
                + RatingStars.accessibilityValue(for: RatingStars.halfRounded(Double(rating)))
        )
    }
}

/// "♡ 1,284": how often the gallery was favourited. A filled heart removes it from favourites;
/// an outlined one offers the ten folders. Logged out it only shows.
private struct FavoriteFigure: View {
    let model: GalleryDetailModel
    let count: Int

    @Environment(UserStore.self) private var userStore

    var body: some View {
        Group {
            if model.isFavorited {
                Button(action: model.unfavorite) { label }
            } else {
                Menu {
                    ForEach(0..<10, id: \.self) { index in
                        Button(folderName(index)) { model.favorite(category: index) }
                    }
                } label: {
                    label
                }
                .menuStyle(.button)
            }
        }
        .buttonStyle(PanelPressButtonStyle())
        .disabled(!model.isLoggedIn)
        .accessibilityLabel(
            model.isFavorited
                ? L10n.Localizable.GalleryInfosView.Title.favorited : L10n.Localizable.TabItem.Title.favorites
        )
        .accessibilityValue(L10n.Localizable.GalleryInfosView.Title.favoritedTimes + ", " + count.formatted())
    }

    private var label: some View {
        FigureLabel(systemImage: model.isFavorited ? "heart.fill" : "heart") {
            Text(count, format: .number)
        }
        .contentTransition(.symbolEffect(.replace))
    }

    private func folderName(_ index: Int) -> String {
        userStore.customFavoriteCategoryName(index: index)
            ?? L10n.Localizable.Struct.User.FavoriteCategory.default("\(index)")
    }
}

/// A symbol and a figure, as the bar draws its rating and favourite count.
private struct FigureLabel<Value: View>: View {
    let systemImage: String
    var symbolStyle: Color = .textPrimary
    @ViewBuilder let value: Value

    var body: some View {
        HStack(spacing: Tokens.Spacing.xSmall + Tokens.Spacing.xxSmall) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .foregroundStyle(symbolStyle)
            value
                .monospacedDigit()
        }
        .font(.headline)
        .foregroundStyle(.textPrimary)
        .lineLimit(1)
        .padding(.horizontal, Tokens.Spacing.large)
        .frame(minHeight: 48)
    }
}

/// "64 pages / English · 212.4 MB ›", leading to Gallery infos.
private struct InfosFigure: View {
    let detail: GalleryDetail
    let showInfos: () -> Void

    var body: some View {
        Button(action: showInfos) {
            HStack(spacing: Tokens.Spacing.xSmall) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.Localizable.Common.Value.pages(detail.pageCount.formatted()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                    Text(verbatim: "\(detail.language.localizedName) · \(detail.formattedSize)")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.textSecondary)
            }
            .padding(.leading, Tokens.Spacing.medium)
            .padding(.trailing, Tokens.Spacing.small)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(PanelPressButtonStyle())
        .accessibilityLabel(L10n.Localizable.GalleryInfosView.Title.galleryInfos)
        .accessibilityValue(
            "\(L10n.Localizable.Common.Value.pages(detail.pageCount.formatted())), "
                + "\(detail.language.localizedName), \(detail.formattedSize)"
        )
    }
}

/// The stars that give a rating: drag or tap, release to submit; they hide a second later.
private struct RatingPanel: View {
    @Bindable var model: GalleryDetailModel

    var body: some View {
        RatingControl(rating: $model.userRating) { model.rate($0) }
            .font(.title)
            .foregroundStyle(.yellow)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: model.ratingCommitCount)
            .padding(.horizontal, Tokens.Spacing.xLarge)
            .padding(.vertical, Tokens.Spacing.medium)
            .glassSurface(in: .capsule, tone: .panel)
    }
}
