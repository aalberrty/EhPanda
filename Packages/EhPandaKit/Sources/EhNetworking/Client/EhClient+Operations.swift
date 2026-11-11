import EhModels
import Foundation

// Operations that change something on the server. The API-based ones need the gallery's
// `apiKey` (from `galleryDetail`) and read the member id from `cookies`.
extension EhClient {
    public func addFavorite(gid: String, token: String, category: Int) async throws {
        throw AppError.unknown
    }

    public func removeFavorite(gid: String) async throws {
        throw AppError.unknown
    }

    /// `rating` counts half stars, 1...10.
    public func rate(gid: String, token: String, apiKey: String, rating: Int) async throws {
        throw AppError.unknown
    }

    public func postComment(_ content: String, galleryURL: URL) async throws {
        throw AppError.unknown
    }

    public func editComment(id commentID: String, content: String, galleryURL: URL) async throws {
        throw AppError.unknown
    }

    /// `vote` is 1 or -1.
    public func voteComment(
        gid: String, token: String, commentID: String, apiKey: String, vote: Int
    ) async throws {
        throw AppError.unknown
    }

    /// `vote` is 1 or -1. `tag` is the tag's vote keyword (`GalleryTag.Content.voteKeyword`).
    public func voteTag(
        gid: String, token: String, tag: String, apiKey: String, vote: Int
    ) async throws {
        throw AppError.unknown
    }
}
