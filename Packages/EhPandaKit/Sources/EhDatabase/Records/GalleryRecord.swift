import EhModels
import Foundation
import GRDB

/// A row of `gallery`: a gallery the user opened.
struct GalleryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = Schema.gallery

    var gid: String
    var token: String
    var title: String
    var rating: Double
    var category: String
    var uploader: String?
    var pageCount: Int
    var postedDate: Date
    var coverURL: URL?
    var galleryURL: URL?
    var tags: String
    var lastOpenDate: Date

    enum Columns {
        static let gid = Column(CodingKeys.gid)
        static let lastOpenDate = Column(CodingKeys.lastOpenDate)
    }

    init(gallery: Gallery, lastOpenDate: Date) throws {
        gid = gallery.gid
        token = gallery.token
        title = gallery.title
        rating = Double(gallery.rating)
        category = gallery.category.rawValue
        uploader = gallery.uploader
        pageCount = gallery.pageCount
        postedDate = gallery.postedDate
        coverURL = gallery.coverURL
        galleryURL = gallery.galleryURL
        tags = try JSONColumn.encode(gallery.tags)
        self.lastOpenDate = lastOpenDate
    }

    var gallery: Gallery {
        Gallery(
            gid: gid,
            token: token,
            title: title,
            rating: Float(rating),
            tags: JSONColumn.decode([GalleryTag].self, from: tags) ?? [],
            // Legacy maps unknown categories to `.private` as well.
            category: Category(rawValue: category) ?? .private,
            uploader: uploader,
            pageCount: pageCount,
            postedDate: postedDate,
            coverURL: coverURL,
            galleryURL: galleryURL,
            lastOpenDate: lastOpenDate
        )
    }
}
