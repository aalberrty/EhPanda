import EhModels
import Foundation

// Operations on a gallery: favourites, archive downloads, ratings, comments and votes.
// `apiuid` is the member id (the `ipb_member_id` cookie) and `apikey` comes from the
// parsed gallery detail page.
extension EhRequestBuilder {
    /// - Parameter favIndex: The favorites category, 0–9.
    public func favorGallery(gid: String, token: String, favIndex: Int) -> URLRequest {
        let url = RequestEncoding.appending([
            RequestEncoding.item(.gid, gid),
            RequestEncoding.item(.token, token),
            RequestEncoding.item(.act, RequestQueryValue.addFavAct)
        ], to: galleryPopupsURL)
        return RequestEncoding.postForm(url, fields: [
            ("favcat", String(favIndex)),
            ("favnote", ""),
            ("apply", "Add to Favorites"),
            ("update", "1")
        ])
    }

    public func unfavorGallery(gid: String) -> URLRequest {
        RequestEncoding.postForm(favoritesURL, fields: [
            ("ddact", "delete"),
            ("modifygids[]", gid),
            ("apply", "Apply")
        ])
    }

    /// Asks the user's H@H client to download the archive.
    /// - Parameter resolution: The archive resolution value the archive page offered.
    public func sendDownloadCommand(archiveURL: URL, resolution: String) -> URLRequest {
        RequestEncoding.postForm(archiveURL, fields: [("hathdl_xres", resolution)])
    }

    /// - Parameter rating: The site's rating scale, 1–10 (half stars).
    public func rateGallery(apiuid: Int, apikey: String, gid: Int, token: String, rating: Int) -> URLRequest {
        RequestEncoding.postJSON(apiURL, body: RateGalleryBody(
            method: "rategallery", apiuid: apiuid, apikey: apikey, gid: gid, token: token, rating: rating
        ))
    }

    /// Posts a comment to the gallery page. Newlines are sent as a literal `%0A`, which the
    /// legacy form encoding escapes again to `%250A`; kept as legacy sent it.
    public func commentGallery(content: String, galleryURL: URL) -> URLRequest {
        RequestEncoding.postForm(galleryURL, fields: [("commenttext_new", newlinesEscaped(content))])
    }

    /// Edits one of the user's comments, with the same newline handling as `commentGallery`.
    public func editGalleryComment(commentID: String, content: String, galleryURL: URL) -> URLRequest {
        RequestEncoding.postForm(galleryURL, fields: [
            ("edit_comment", commentID),
            ("commenttext_edit", newlinesEscaped(content))
        ])
    }

    /// - Parameter commentVote: `1` to vote up, `-1` to vote down.
    public func voteGalleryComment(
        apiuid: Int, apikey: String, gid: Int, token: String, commentID: Int, commentVote: Int
    ) -> URLRequest {
        RequestEncoding.postJSON(apiURL, body: VoteCommentBody(
            method: "votecomment", apiuid: apiuid, apikey: apikey, gid: gid, token: token,
            commentID: commentID, commentVote: commentVote
        ))
    }

    /// - Parameters:
    ///   - tag: The tag as `namespace:name`.
    ///   - vote: `1` to vote up, `-1` to vote down.
    public func voteGalleryTag(
        apiuid: Int, apikey: String, gid: Int, token: String, tag: String, vote: Int
    ) -> URLRequest {
        RequestEncoding.postJSON(apiURL, body: VoteTagBody(
            method: "taggallery", apiuid: apiuid, apikey: apikey, gid: gid, token: token,
            tags: tag, vote: vote
        ))
    }

    private func newlinesEscaped(_ content: String) -> String {
        content.replacingOccurrences(of: "\n", with: "%0A")
    }
}

private struct RateGalleryBody: Encodable {
    let method: String
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let rating: Int
}

private struct VoteCommentBody: Encodable {
    let method: String
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let commentID: Int
    let commentVote: Int

    enum CodingKeys: String, CodingKey {
        case method, apiuid, apikey, gid, token
        case commentID = "comment_id"
        case commentVote = "comment_vote"
    }
}

private struct VoteTagBody: Encodable {
    let method: String
    let apiuid: Int
    let apikey: String
    let gid: Int
    let token: String
    let tags: String
    let vote: Int
}
