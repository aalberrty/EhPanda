import EhFeatures
import EhModels
import SwiftUI

/// "Give a rating" with its stars, and "Similar gallery".
struct DetailActionsSection: View {
    @Bindable var model: GalleryDetailModel

    @Environment(StackRouter.self) private var stack: StackRouter?
    @State private var searchCount = 0

    var body: some View {
        VStack(spacing: Tokens.Spacing.medium) {
            HStack(spacing: Tokens.Spacing.medium) {
                Button {
                    withAnimation { model.toggleRatingControl() }
                } label: {
                    Label(L10n.Localizable.DetailView.ActionSection.Button.giveARating, systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!model.isLoggedIn)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: model.showsRatingControl)

                Button {
                    guard let detail = model.detail else { return }
                    searchCount += 1
                    stack?.push(.search(keyword: DetailSearchKeyword.similar(to: detail)))
                } label: {
                    Label(
                        L10n.Localizable.DetailView.ActionSection.Button.similarGallery,
                        systemImage: "photo.on.rectangle.angled"
                    )
                    .frame(maxWidth: .infinity)
                }
                .sensoryFeedback(.impact(flexibility: .soft), trigger: searchCount)
            }
            .font(.callout.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .glassButtonStyle()
            .controlSize(.large)

            if model.showsRatingControl {
                RatingControl(rating: $model.userRating) { model.rate($0) }
                    .font(.title)
                    .foregroundStyle(.yellow)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: model.ratingCommitCount)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.default, value: model.showsRatingControl)
    }
}
