import GRDB

/// Table and column names, and the migrations that create them.
///
/// JSON columns hold UTF-8 text written by GRDB's JSON encoder. Dates are GRDB's default
/// `yyyy-MM-dd HH:mm:ss.SSS` UTC text, which sorts chronologically.
enum Schema {
    static let gallery = "gallery"
    static let galleryDetail = "galleryDetail"
    static let galleryState = "galleryState"
    static let galleryPage = "galleryPage"
    static let tagTranslation = "tagTranslation"
    static let searchHistory = "searchHistory"
    static let quickSearchWord = "quickSearchWord"

    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1") { db in
            try createGalleryTables(db)
            try createGalleryPageTable(db)
            try createSearchTables(db)
        }
    }

    private static func createGalleryTables(_ db: Database) throws {
        // Only galleries the user opened are stored, so `lastOpenDate` is never NULL and
        // history is this table ordered by it.
        try db.create(table: gallery) { table in
            table.primaryKey("gid", .text)
            table.column("token", .text).notNull()
            table.column("title", .text).notNull()
            table.column("rating", .double).notNull()
            table.column("category", .text).notNull()
            table.column("uploader", .text)
            table.column("pageCount", .integer).notNull()
            table.column("postedDate", .datetime).notNull()
            table.column("coverURL", .text)
            table.column("galleryURL", .text)
            table.column("tags", .jsonText).notNull()
            table.column("lastOpenDate", .datetime).notNull().indexed()
        }

        try db.create(table: galleryDetail) { table in
            table.primaryKey("gid", .text)
            table.column("title", .text).notNull()
            table.column("jpnTitle", .text)
            table.column("isFavorited", .boolean).notNull()
            table.column("visibility", .jsonText).notNull()
            table.column("rating", .double).notNull()
            table.column("userRating", .double).notNull()
            table.column("ratingCount", .integer).notNull()
            table.column("category", .text).notNull()
            table.column("language", .text).notNull()
            table.column("uploader", .text).notNull()
            table.column("postedDate", .datetime).notNull()
            table.column("coverURL", .text)
            table.column("archiveURL", .text)
            table.column("parentURL", .text)
            table.column("favoritedCount", .integer).notNull()
            table.column("pageCount", .integer).notNull()
            table.column("sizeCount", .double).notNull()
            table.column("sizeType", .text).notNull()
            table.column("torrentCount", .integer).notNull()
        }

        // One row per gallery. A fetched detail page writes the three JSON columns together and
        // leaves `readingProgress`, which the reader writes on its own.
        try db.create(table: galleryState) { table in
            table.primaryKey("gid", .text)
            table.column("readingProgress", .integer).notNull().defaults(to: 0)
            table.column("previewConfig", .jsonText)
            table.column("tags", .jsonText)
            table.column("comments", .jsonText)
        }
    }

    private static func createGalleryPageTable(_ db: Database) throws {
        // One row per page replaces legacy's four `[Int: URL]` blobs. WITHOUT ROWID keeps
        // rows clustered by (gid, pageIndex), which is the only access path.
        try db.create(table: galleryPage, options: .withoutRowID) { table in
            table.column("gid", .text).notNull()
            table.column("pageIndex", .integer).notNull()
            table.column("pageURL", .text)
            table.column("imageURL", .text)
            table.column("originalImageURL", .text)
            table.column("previewURL", .text)
            table.column("imageWidth", .integer)
            table.column("imageHeight", .integer)
            table.primaryKey(["gid", "pageIndex"])
        }
    }

    private static func createSearchTables(_ db: Database) throws {
        try db.create(table: tagTranslation) { table in
            table.primaryKey("key", .text)
            table.column("namespace", .text).notNull()
            table.column("tag", .text).notNull()
            table.column("value", .text).notNull()
            table.column("displayValue", .text).notNull()
            table.column("valueImageURL", .text)
            table.column("description", .text)
            table.column("linksString", .text)
        }

        try db.create(table: searchHistory) { table in
            table.primaryKey("keyword", .text)
            table.column("lastUsedAt", .datetime).notNull().indexed()
        }

        try db.create(table: quickSearchWord) { table in
            table.primaryKey("id", .text)
            table.column("name", .text).notNull()
            table.column("content", .text).notNull()
            table.column("position", .integer).notNull().indexed()
        }
    }
}
