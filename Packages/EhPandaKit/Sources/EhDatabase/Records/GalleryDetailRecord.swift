import EhModels
import Foundation
import GRDB

/// A row of `galleryDetail`: the last fetched detail of a gallery, shown while it reloads.
struct GalleryDetailRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = Schema.galleryDetail

    var gid: String
    var title: String
    var jpnTitle: String?
    var isFavorited: Bool
    var visibility: String
    var rating: Double
    var userRating: Double
    var ratingCount: Int
    var category: String
    var language: String
    var uploader: String
    var postedDate: Date
    var coverURL: URL?
    var archiveURL: URL?
    var parentURL: URL?
    var favoritedCount: Int
    var pageCount: Int
    var sizeCount: Double
    var sizeType: String
    var torrentCount: Int

    init(detail: GalleryDetail) throws {
        gid = detail.gid
        title = detail.title
        jpnTitle = detail.jpnTitle
        isFavorited = detail.isFavorited
        visibility = try JSONColumn.encode(detail.visibility)
        rating = Double(detail.rating)
        userRating = Double(detail.userRating)
        ratingCount = detail.ratingCount
        category = detail.category.rawValue
        language = detail.language.rawValue
        uploader = detail.uploader
        postedDate = detail.postedDate
        coverURL = detail.coverURL
        archiveURL = detail.archiveURL
        parentURL = detail.parentURL
        favoritedCount = detail.favoritedCount
        pageCount = detail.pageCount
        sizeCount = Double(detail.sizeCount)
        sizeType = detail.sizeType
        torrentCount = detail.torrentCount
    }

    var detail: GalleryDetail {
        GalleryDetail(
            gid: gid,
            title: title,
            jpnTitle: jpnTitle,
            isFavorited: isFavorited,
            visibility: JSONColumn.decode(GalleryVisibility.self, from: visibility) ?? .yes,
            rating: Float(rating),
            userRating: Float(userRating),
            ratingCount: ratingCount,
            category: Category(rawValue: category) ?? .private,
            language: Language(rawValue: language) ?? .invalid,
            uploader: uploader,
            postedDate: postedDate,
            coverURL: coverURL,
            archiveURL: archiveURL,
            parentURL: parentURL,
            favoritedCount: favoritedCount,
            pageCount: pageCount,
            sizeCount: Float(sizeCount),
            sizeType: sizeType,
            torrentCount: torrentCount
        )
    }
}
