import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The detail screen: one lazy scroll of sections, each reading only the model properties it
/// draws, plus the toolbar and every screen the detail presents.
struct GalleryDetailView: View {
    @Bindable var model: GalleryDetailModel

    @Environment(AppRouter.self) private var appRouter: AppRouter?
    @Environment(StackRouter.self) private var stack: StackRouter?

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await model.load() }
            // Pushed children are entries of the stack's path, never pushed from here.
            .onChange(of: model.pushedDestination, initial: true) { _, destination in
                guard let destination, let stack else { return }
                stack.push(.detailChild(DetailChildRoute(parent: model, destination: destination)))
                model.pushedDestination = nil
            }
            .sheet(item: $model.sheetDestination) { destination in
                DetailSheet(destination: destination, model: model)
            }
            .fullScreenCover(item: $model.fullScreenDestination) { destination in
                if case .reader(let page) = destination {
                    ReaderScreen(gallery: model.gallery, initialPage: page)
                }
            }
            .sensoryFeedback(trigger: model.feedback) { _, feedback in
                feedback.map { $0.isSuccess ? .success : .error }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: model.destination) { _, destination in
                destination.map { $0.presentation != .push } ?? false
            }
            .onChange(of: model.greetingToAnnounce, initial: true) { _, greeting in
                guard let greeting, let appRouter else { return }
                appRouter.presentedGreeting = greeting
                model.greetingAnnounced()
            }
    }

    @ViewBuilder
    private var content: some View {
        if model.detail != nil {
            DetailContent(model: model)
        } else if let error = model.loadingState.failed {
            ErrorStateView(error: error, retry: error.isRetryable ? { model.refetch() } : nil)
        } else {
            LoadingStateView()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ToolbarFeaturesMenu {
                Button(L10n.Localizable.DetailView.ToolbarItem.Button.archives, systemImage: "doc.zipper") {
                    model.showArchives()
                }
                .disabled(!model.canOpenArchives)
                Button(torrentsTitle, systemImage: "leaf") {
                    model.showTorrents()
                }
                .disabled(model.torrentCount == 0)
                if let galleryURL = model.gallery.galleryURL {
                    ShareLink(item: galleryURL) {
                        Label(L10n.Localizable.DetailView.ToolbarItem.Button.share, systemImage: "square.and.arrow.up")
                    }
                }
            }
            .disabled(!model.isMenuEnabled)
        }
    }

    private var torrentsTitle: String {
        let title = L10n.Localizable.DetailView.ToolbarItem.Button.torrents
        return model.torrentCount > 0 ? "\(title) (\(model.torrentCount))" : title
    }
}

/// The scrolling content once there is a detail to show.
private struct DetailContent: View {
    let model: GalleryDetailModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Tokens.Spacing.xxLarge) {
                DetailHeaderSection(model: model)
                    .padding(.horizontal)
                DetailDescriptionSection(model: model)
                DetailActionsSection(model: model)
                    .padding(.horizontal)
                DetailTagsSection(model: model)
                    .padding(.horizontal)
                DetailPreviewsSection(model: model)
                DetailCommentsSection(model: model)
            }
            .padding(.bottom, Tokens.Spacing.xLarge)
        }
        .scrollIndicators(.hidden)
        .background {
            DetailBackdrop(model: model)
        }
    }
}

/// The sheets presented from the detail screen.
private struct DetailSheet: View {
    let destination: DetailDestination
    let model: GalleryDetailModel

    var body: some View {
        switch destination {
        case .archives(let archiveURL):
            ArchivesSheet(gallery: model.gallery, archiveURL: archiveURL)
        case .torrents:
            TorrentsSheet(gid: model.gallery.gid, token: model.gallery.token)
        case .postComment:
            PostCommentSheet(composer: .new) { text in model.postComment(text) }
        case .tagDetail(let detail):
            TagDetailSheet(detail: detail)
        case .comments, .previews, .galleryInfos, .reader:
            EmptyView()
        }
    }
}
