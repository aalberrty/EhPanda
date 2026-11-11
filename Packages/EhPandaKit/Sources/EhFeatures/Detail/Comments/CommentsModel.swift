import Dependencies
import EhCore
import EhDatabase
import EhModels
import EhNetworking
import Foundation
import Observation

/// The full comments screen. The comments themselves belong to the gallery's detail model,
/// which refreshes them after every operation; this model adds what only this screen does:
/// composing and editing, votes, links, and scrolling to a linked comment.
@Observable
public final class CommentsModel {
    public let detail: GalleryDetailModel

    /// The comment to bring to the top of the list.
    public private(set) var scrollTarget: String?
    /// The comment being highlighted after a scroll, and its row's opacity.
    public private(set) var highlightedCommentID: String?
    public private(set) var highlightOpacity: Double = 1
    /// Progress of opening a link to a gallery the app has not seen yet.
    public private(set) var linkState: LinkState?
    /// The post / edit sheet.
    public var composer: CommentComposer?

    public enum LinkState: Equatable, Sendable {
        case resolving
        case failed(AppError)
    }

    @ObservationIgnored private var pendingScrollTarget: String?
    @ObservationIgnored private let tasks = ModelTasks()

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.database) private var database
    @ObservationIgnored @Dependency(\.applicationClient) private var application
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.continuousClock) private var clock

    /// - Parameter commentID: A comment to scroll to and highlight once it is in the list.
    public init(detail: GalleryDetailModel, scrollTo commentID: String? = nil) {
        self.detail = detail
        pendingScrollTarget = commentID
    }

    public var comments: [CommentItem] { detail.comments }
    public var canCompose: Bool { detail.isLoggedIn }

    // MARK: Scrolling to a comment

    /// Whether the comment to scroll to has arrived; the view runs `scrollToTarget()` when it has.
    public var isScrollTargetReady: Bool {
        guard let pendingScrollTarget else { return false }
        return detail.comments.contains { $0.id == pendingScrollTarget }
    }

    /// Legacy's sequence: after 0.75 s scroll the comment to the top and fade its row to 25 %,
    /// bring it back at 1.25 s, and forget the target at 2 s.
    public func scrollToTarget() async {
        guard isScrollTargetReady, let target = pendingScrollTarget else { return }
        pendingScrollTarget = nil
        do {
            try await clock.sleep(for: .milliseconds(750))
            scrollTarget = target
            highlightedCommentID = target
            highlightOpacity = 0.25
            try await clock.sleep(for: .milliseconds(500))
            highlightOpacity = 1
            try await clock.sleep(for: .milliseconds(750))
        } catch {
            highlightOpacity = 1
        }
        highlightedCommentID = nil
        scrollTarget = nil
    }

    // MARK: Composing and voting

    public func compose() {
        guard canCompose else { return }
        composer = .new
    }

    /// Opens the editor pre-filled with the comment's text and links.
    public func edit(_ item: CommentItem) {
        guard item.comment.editable else { return }
        composer = .edit(commentID: item.id, text: item.comment.plainTextContent)
    }

    /// Sends the composed text and closes the sheet at once; the result shows only as a haptic
    /// and a refreshed list, as in legacy.
    public func submit(_ text: String, for composer: CommentComposer) {
        switch composer {
        case .new:
            detail.postComment(text)
        case .edit(let commentID, _):
            detail.editComment(id: commentID, text: text)
        }
        self.composer = nil
    }

    public func vote(_ item: CommentItem, up: Bool) {
        guard item.comment.votable else { return }
        detail.voteComment(id: item.id, vote: up ? 1 : -1)
    }

    // MARK: Links

    /// Gallery and image-page links on E-Hentai / ExHentai open in the app: the gallery is
    /// pushed onto `stack` as `Route.detail`, whose intent opens the reader at the linked page
    /// or the comments at the linked comment. Anything else opens outside the app.
    ///
    /// A gallery the app has not stored is first resolved from the site behind a HUD. Like
    /// links from outside the app, the link moves to the selected host when "Redirects links
    /// to the selected host" is on.
    public func openLink(_ link: URL, on stack: StackRouter) {
        guard EhURL.isHandleable(link), let gid = EhURL.galleryID(of: link) else {
            let application = application
            Task { _ = await application.openURL(link) }
            return
        }
        let redirection = LinkRedirection(settings: settings)
        let url = redirection.redirect(link)
        let analysis = EhURL.analyze(url)
        tasks.run("link") { [weak self, database, client] in
            if let stored = try? await database.gallery(gid: gid) {
                guard !Task.isCancelled else { return }
                self?.open(redirection.redirect(stored), analysis: analysis, on: stack)
                return
            }
            self?.linkState = .resolving
            let outcome = await Outcome.of { try await client.gallery(from: url) }
            guard let self else { return }
            switch outcome {
            case .success(let gallery):
                linkState = nil
                open(gallery, analysis: analysis, on: stack)
            case .failure(let error):
                // Legacy cleared the HUD before switching it to the error, so this never showed.
                linkState = .failed(error)
            case .cancelled:
                linkState = nil
            }
        }
    }

    /// Called when the error HUD hides itself.
    public func dismissLinkState() {
        if case .failed = linkState {
            linkState = nil
        }
    }

    private func open(_ gallery: Gallery, analysis: EhLinkAnalysis, on stack: StackRouter) {
        var intent: DetailIntent?
        if let page = analysis.pageIndex {
            let database = database
            Task { try? await database.updateReadingProgress(gid: gallery.gid, progress: page) }
            intent = .read(page: page)
        } else if let commentID = analysis.commentID {
            intent = .comments(scrollTo: commentID)
        }
        stack.push(.detail(gallery, intent: intent))
    }
}

/// What the post-comment sheet is for.
public enum CommentComposer: Identifiable, Hashable, Sendable {
    case new
    case edit(commentID: String, text: String)

    public var id: Self { self }

    /// The text the editor starts with.
    public var initialText: String {
        switch self {
        case .new: ""
        case .edit(_, let text): text
        }
    }

    public var isEditing: Bool {
        if case .edit = self { true } else { false }
    }
}
