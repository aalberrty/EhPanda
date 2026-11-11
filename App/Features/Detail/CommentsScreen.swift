import EhFeatures
import EhModels
import SwiftUI

/// Every comment of the gallery, with votes, editing, composing and in-app links.
struct CommentsScreen: View {
    @State private var model: CommentsModel

    init(detail: GalleryDetailModel, scrollTo commentID: String?) {
        _model = State(initialValue: CommentsModel(detail: detail, scrollTo: commentID))
    }

    var body: some View {
        ScrollViewReader { proxy in
            List(model.comments) { item in
                CommentRow(item: item)
                    .equatable()
                    .opacity(item.id == model.highlightedCommentID ? model.highlightOpacity : 1)
                    .swipeActions(edge: .leading) {
                        if item.comment.votable {
                            Button {
                                model.vote(item, up: false)
                            } label: {
                                Label(L10n.Localizable.DetailView.ContextMenu.Button.voteDown, systemImage: "hand.thumbsdown")
                            }
                            .tint(.red)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if item.comment.votable {
                            Button {
                                model.vote(item, up: true)
                            } label: {
                                Label(L10n.Localizable.DetailView.ContextMenu.Button.voteUp, systemImage: "hand.thumbsup")
                            }
                            .tint(.green)
                        }
                        if item.comment.editable {
                            Button {
                                model.edit(item)
                            } label: {
                                Label(L10n.Localizable.PostCommentView.Title.editComment, systemImage: "square.and.pencil")
                            }
                        }
                    }
            }
            .listStyle(.plain)
            .animation(.default, value: model.highlightOpacity)
            .onChange(of: model.scrollTarget) { _, target in
                guard let target else { return }
                withAnimation { proxy.scrollTo(target, anchor: .top) }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            model.openLink(url)
            return .handled
        })
        .navigationDestination(item: $model.linkedGallery) { gallery in
            GalleryDetailDestination(gallery: gallery)
        }
        .task(id: model.isScrollTargetReady) { await model.scrollToTarget() }
        .navigationTitle(L10n.Localizable.CommentsView.Title.comments)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.Localizable.PostCommentView.Title.postComment, systemImage: "square.and.pencil") {
                    model.compose()
                }
                .disabled(!model.canCompose)
            }
        }
        .sheet(item: $model.composer) { composer in
            PostCommentSheet(composer: composer) { text in model.submit(text, for: composer) }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.composer) { _, composer in composer != nil }
        .hud(linkHUD)
    }

    private var linkHUD: Binding<HUDConfiguration?> {
        Binding(
            get: {
                switch model.linkState {
                case .resolving: .loading
                case .failed(let error): .error(caption: error.alertText)
                case nil: nil
                }
            },
            set: { if $0 == nil { model.dismissLinkState() } }
        )
    }
}

/// One comment: the header, then each block of its body. Links are `link` runs of the text, so
/// they render tinted and go through the screen's `openURL` action.
struct CommentRow: View, Equatable {
    let item: CommentItem

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            CommentHeader(item: item)
            ForEach(item.blocks.indices, id: \.self) { index in
                switch item.blocks[index] {
                case .text(let text):
                    Text(text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                case .images(let images):
                    CommentImages(images: images)
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.small)
    }
}

/// One image at half the list's width, or two at a quarter each, optionally linked.
private struct CommentImages: View {
    let images: [CommentImage]

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 0) {
            ForEach(images.indices, id: \.self) { index in
                let image = images[index]
                let fraction: CGFloat = images.count > 1 ? 4 : 2
                RemoteImage(url: image.imageURL, width: 600 / fraction)
                    .containerRelativeFrame(.horizontal) { width, _ in width / fraction }
                    .onTapGesture {
                        if let link = image.link { openURL(link) }
                    }
                    .accessibilityAddTraits(image.link == nil ? [] : .isLink)
            }
        }
    }
}
