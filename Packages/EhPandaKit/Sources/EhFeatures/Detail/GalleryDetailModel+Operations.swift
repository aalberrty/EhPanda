import EhModels
import Foundation

// Server operations and the screens the detail screen opens.
//
// Legacy behaviour kept here: every operation is offered only to a logged-in user; on success
// the screen gives a success haptic and fetches the whole page again, on failure an error
// haptic, and nothing else. Ratings and votes go through the site's API, which takes the
// member id and gid as numbers; when either is not a number legacy silently did nothing.
extension GalleryDetailModel {
    // MARK: Favourites

    /// Adds the gallery to favourites folder `category` (0...9).
    public func favorite(category: Int) {
        guard isLoggedIn else { return }
        let client = client
        let gid = gallery.gid
        let token = gallery.token
        perform("favorite") { try await client.addFavorite(gid: gid, token: token, category: category) }
    }

    public func unfavorite() {
        guard isLoggedIn else { return }
        let client = client
        let gid = gallery.gid
        perform("favorite") { try await client.removeFavorite(gid: gid) }
    }

    // MARK: Rating

    /// Shows or hides the rating stars ("Give a rating").
    public func toggleRatingControl() {
        guard isLoggedIn else { return }
        showsRatingControl.toggle()
    }

    /// Submits a rating in half stars (1...10) and hides the stars a second later.
    public func rate(_ halfStars: Int) {
        guard isLoggedIn else { return }
        userRating = halfStars
        ratingCommitCount += 1
        tasks.run("hideRating") { [weak self, clock] in
            try? await clock.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.showsRatingControl = false
        }
        guard canUseAPI else { return }
        let client = client
        let gid = gallery.gid
        let token = gallery.token
        let apiKey = apiKey
        perform("rate") { try await client.rate(gid: gid, token: token, apiKey: apiKey, rating: halfStars) }
    }

    // MARK: Comments

    /// Posts a new comment. Empty text is ignored, as the sheet's Confirm button is disabled.
    public func postComment(_ text: String) {
        guard isLoggedIn, !text.isEmpty, let galleryURL = gallery.galleryURL else { return }
        let client = client
        perform("comment") { try await client.postComment(text, galleryURL: galleryURL) }
    }

    public func editComment(id commentID: String, text: String) {
        guard isLoggedIn, !text.isEmpty, let galleryURL = gallery.galleryURL else { return }
        let client = client
        perform("comment") { try await client.editComment(id: commentID, content: text, galleryURL: galleryURL) }
    }

    /// `vote` is 1 (up) or -1 (down).
    public func voteComment(id commentID: String, vote: Int) {
        guard canUseAPI, Int(commentID) != nil else { return }
        let client = client
        let gid = gallery.gid
        let token = gallery.token
        let apiKey = apiKey
        perform("voteComment") {
            try await client.voteComment(gid: gid, token: token, commentID: commentID, apiKey: apiKey, vote: vote)
        }
    }

    // MARK: Tags

    /// `vote` is 1 (up) or -1 (down); withdrawing sends the opposite of the current vote.
    public func voteTag(_ chip: DetailTagChip, vote: Int) {
        guard isLoggedIn, canUseAPI else { return }
        let client = client
        let gid = gallery.gid
        let token = gallery.token
        let apiKey = apiKey
        let tag = chip.voteKeyword
        perform("voteTag") { try await client.voteTag(gid: gid, token: token, tag: tag, apiKey: apiKey, vote: vote) }
    }

    // MARK: Destinations

    /// Opens the reader. With a page, that page also becomes the stored reading progress, as
    /// legacy did when a preview was tapped.
    public func openReader(page: Int? = nil) {
        if let page {
            let database = database
            let gid = gallery.gid
            Task { try? await database.updateReadingProgress(gid: gid, progress: page) }
        }
        destination = .reader(page: page)
    }

    public func showArchives() {
        guard canOpenArchives, let archiveURL = detail?.archiveURL else { return }
        destination = .archives(archiveURL: archiveURL)
    }

    public func showTorrents() {
        guard torrentCount > 0 else { return }
        destination = .torrents
    }

    public func showPostComment() {
        guard isLoggedIn else { return }
        destination = .postComment
    }

    public func showTagDetail(_ detail: TagDetail) {
        destination = .tagDetail(detail)
    }

    /// The pushed child the screen asked for. The view hands it to its stack as
    /// `Route.detailChild` and clears it; it is never presented outside the stack's path.
    public var pushedDestination: DetailDestination? {
        get { destination?.presentation == .push ? destination : nil }
        set { replaceDestination(of: .push, with: newValue) }
    }

    /// The sheet, as a binding target for `sheet(item:)`.
    public var sheetDestination: DetailDestination? {
        get { destination?.presentation == .sheet ? destination : nil }
        set { replaceDestination(of: .sheet, with: newValue) }
    }

    /// The reader, as a binding target for `fullScreenCover(item:)`.
    public var fullScreenDestination: DetailDestination? {
        get { destination?.presentation == .fullScreen ? destination : nil }
        set { replaceDestination(of: .fullScreen, with: newValue) }
    }

    // MARK: Plumbing

    /// Dismissing one kind of presentation clears the destination only if it is still that kind.
    private func replaceDestination(of presentation: DetailDestination.Presentation, with newValue: DetailDestination?) {
        if let newValue {
            destination = newValue
        } else if destination?.presentation == presentation {
            destination = nil
        }
    }

    private var canUseAPI: Bool {
        Int(gallery.gid) != nil && Int(client.cookies.memberID(for: settings.galleryHost)) != nil
    }

    /// Runs one operation: success → success haptic and a fresh page; failure → error haptic.
    func perform(_ key: String, _ operation: @escaping @Sendable () async throws -> Void) {
        tasks.run(key) { [weak self] in
            let outcome = await Outcome.of(operation)
            self?.finishOperation(outcome)
        }
    }

    private func finishOperation(_ outcome: Outcome<Void>) {
        switch outcome {
        case .success:
            feedback = feedbackCounter.next(.success)
            refetch()
        case .failure:
            feedback = feedbackCounter.next(.failure)
        case .cancelled:
            break
        }
    }
}
