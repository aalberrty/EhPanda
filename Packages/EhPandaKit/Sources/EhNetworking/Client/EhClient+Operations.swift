import EhModels
import Foundation

// Operations that change something on the server. The API-based ones need the gallery's
// `apiKey` (from `galleryDetail`) and read the member id from `cookies`.
//
// Legacy ignored every response body here, so only transport failures are reported. The API
// takes numeric ids; a gid, comment id or member id (no login) that is not a number throws
// `AppError.unknown` before anything is sent, where legacy silently skipped the request.
extension EhClient {
    public func addFavorite(gid: String, token: String, category: Int) async throws {
        try await perform { builder in
            try await fire(builder.favorGallery(gid: gid, token: token, favIndex: category))
        }
    }

    public func removeFavorite(gid: String) async throws {
        try await perform { builder in
            try await fire(builder.unfavorGallery(gid: gid))
        }
    }

    /// `rating` counts half stars, 1...10.
    public func rate(gid: String, token: String, apiKey: String, rating: Int) async throws {
        try await perform { builder in
            try await fire(builder.rateGallery(
                apiuid: memberID(for: builder.host), apikey: apiKey, gid: number(gid), token: token, rating: rating
            ))
        }
    }

    public func postComment(_ content: String, galleryURL: URL) async throws {
        try await perform { builder in
            try await fire(builder.commentGallery(content: content, galleryURL: galleryURL))
        }
    }

    public func editComment(id commentID: String, content: String, galleryURL: URL) async throws {
        try await perform { builder in
            try await fire(builder.editGalleryComment(commentID: commentID, content: content, galleryURL: galleryURL))
        }
    }

    /// `vote` is 1 or -1.
    public func voteComment(
        gid: String, token: String, commentID: String, apiKey: String, vote: Int
    ) async throws {
        try await perform { builder in
            try await fire(builder.voteGalleryComment(
                apiuid: memberID(for: builder.host), apikey: apiKey, gid: number(gid), token: token,
                commentID: number(commentID), commentVote: vote
            ))
        }
    }

    /// `vote` is 1 or -1. `tag` is the tag's vote keyword (`GalleryTag.Content.voteKeyword`).
    public func voteTag(
        gid: String, token: String, tag: String, apiKey: String, vote: Int
    ) async throws {
        try await perform { builder in
            try await fire(builder.voteGalleryTag(
                apiuid: memberID(for: builder.host), apikey: apiKey, gid: number(gid), token: token,
                tag: tag, vote: vote
            ))
        }
    }
}
