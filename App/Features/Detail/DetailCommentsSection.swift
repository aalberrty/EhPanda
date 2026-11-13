import EhFeatures
import EhModels
import SwiftUI

/// The first comments on a glass panel, "Show all" for the full list, and "Post comment".
struct DetailCommentsSection: View {
    let model: GalleryDetailModel

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            DetailPanelHeader(
                title: L10n.Localizable.DetailView.Section.Title.comments,
                count: model.comments.isEmpty ? nil : model.comments.count,
                showsAll: !model.comments.isEmpty,
                showAll: { model.destination = .comments(scrollTo: nil) }
            )
            if !model.comments.isEmpty {
                CommentPreviews(comments: Array(model.comments.prefix(Self.previewCount)))
                    .equatable()
            }
            Button(action: model.showPostComment) {
                Label(L10n.Localizable.DetailView.Button.postComment, systemImage: "square.and.pencil")
            }
            .buttonStyle(PanelFillButtonStyle())
            .disabled(!model.isLoggedIn)
            .padding(.top, Tokens.Spacing.xSmall)
        }
        .padding(.horizontal, Tokens.Spacing.large)
        .padding(.top, Tokens.Spacing.medium)
        .padding(.bottom, Tokens.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private static let previewCount = 3
}

private struct CommentPreviews: View, Equatable {
    let comments: [CommentItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            ForEach(comments) { item in
                if item.id != comments.first?.id {
                    Rectangle()
                        .fill(.hairline)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
                    CommentHeader(item: item)
                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Author, vote marker, score and date, shared by the panel and the comments list.
struct CommentHeader: View {
    let item: CommentItem

    var body: some View {
        HStack(spacing: Tokens.Spacing.xSmall) {
            Text(item.author)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textPrimary)
            Spacer(minLength: Tokens.Spacing.small)
            Group {
                if item.comment.votedUp {
                    Image(systemName: "hand.thumbsup.fill")
                        .accessibilityLabel(L10n.Localizable.DetailView.ContextMenu.Button.voteUp)
                } else if item.comment.votedDown {
                    Image(systemName: "hand.thumbsdown.fill")
                        .accessibilityLabel(L10n.Localizable.DetailView.ContextMenu.Button.voteDown)
                }
                if let score = item.comment.score {
                    Text(score)
                }
                Text(item.comment.formattedDateString)
            }
            .font(.footnote)
            .foregroundStyle(.textSecondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
