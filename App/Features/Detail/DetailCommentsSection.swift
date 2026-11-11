import EhFeatures
import EhModels
import SwiftUI

/// Up to six comment cards and the "Post comment" button.
struct DetailCommentsSection: View {
    let model: GalleryDetailModel

    var body: some View {
        SubSection(
            title: L10n.Localizable.DetailView.Section.Title.comments,
            showsAll: !model.comments.isEmpty,
            showAll: { model.destination = .comments(scrollTo: nil) }
        ) {
            VStack(spacing: Tokens.Spacing.medium) {
                if !model.comments.isEmpty {
                    CommentCardsRow(comments: Array(model.comments.prefix(6)))
                        .equatable()
                }
                Button(action: model.showPostComment) {
                    Label(L10n.Localizable.DetailView.Button.postComment, systemImage: "square.and.pencil")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                }
                .glassButtonStyle()
                .controlSize(.large)
                .disabled(!model.isLoggedIn)
                .padding(.horizontal)
            }
        }
    }
}

private struct CommentCardsRow: View, Equatable {
    let comments: [CommentItem]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Tokens.Spacing.small) {
                ForEach(comments) { item in
                    CommentCard(item: item)
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Tokens.Spacing.large, for: .scrollContent)
    }
}

private struct CommentCard: View {
    let item: CommentItem

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
            CommentHeader(item: item)
            Text(item.summary)
                .font(.callout)
                .lineLimit(3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding()
        .frame(width: 300, height: 120)
        .background(.fill.quaternary, in: .rect(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Author, vote marker, score and date, shared by the cards and the comments list.
struct CommentHeader: View {
    let item: CommentItem

    var body: some View {
        HStack(spacing: Tokens.Spacing.xSmall) {
            Text(item.author)
                .font(.subheadline.bold())
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
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
