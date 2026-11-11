import EhModels
import Foundation

/// Values for building test rows.
enum SampleData {
    /// A whole-second date, so it survives GRDB's millisecond date text unchanged.
    static func date(_ secondsSinceReferenceDate: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: secondsSinceReferenceDate)
    }

    static func tags(_ text: String = "glasses") -> [GalleryTag] {
        [GalleryTag(rawNamespace: "female", contents: [
            .init(rawNamespace: "female", text: text, isVotedUp: true, isVotedDown: false,
                  backgroundColor: RGBColor(red: 1, green: 0, blue: 0))
        ])]
    }

    static func gallery(_ gid: String, title: String = "Title", lastOpenDate: Date? = nil) -> Gallery {
        Gallery(
            gid: gid, token: "token\(gid)", title: title, rating: 3.5, tags: tags(),
            category: .manga, uploader: "uploader", pageCount: 42, postedDate: date(700_000_000),
            coverURL: URL(string: "https://ehgt.org/\(gid).jpg"),
            galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token\(gid)/"),
            lastOpenDate: lastOpenDate
        )
    }

    static func detail(_ gid: String) -> GalleryDetail {
        GalleryDetail(
            gid: gid, title: "Title", jpnTitle: "タイトル", isFavorited: true,
            visibility: .no(reason: "Expunged"), rating: 4.5, userRating: 3, ratingCount: 120,
            category: .doujinshi, language: .japanese, uploader: "someone",
            postedDate: date(700_000_000), coverURL: URL(string: "https://ehgt.org/c.jpg"),
            archiveURL: URL(string: "https://e-hentai.org/archiver.php?gid=\(gid)"),
            parentURL: nil, favoritedCount: 10, pageCount: 24, sizeCount: 12.5,
            sizeType: "MB", torrentCount: 2
        )
    }

    static let commentContentID = UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))

    static func comments() -> [GalleryComment] {
        [GalleryComment(
            votedUp: true, votedDown: false, votable: true, editable: false, score: "+3",
            author: "someone", contents: [CommentContent(id: commentContentID, type: .plainText, text: "Nice")],
            commentID: "1", commentDate: date(700_000_100)
        )]
    }

    static func url(_ string: String) -> URL? {
        URL(string: "https://e-hentai.org/\(string)")
    }
}
