import Foundation
import GRDB

// MARK: - Pages

extension AppDatabase {
    /// Inserts or merges `pages` in one transaction. For an existing page only the non-`nil`
    /// fields of the new value overwrite what is stored.
    public func upsertPages(_ pages: [GalleryPage]) async throws {
        guard !pages.isEmpty else { return }
        try await writer.write { db in
            try Self.upsert(pages, in: db)
        }
    }

    /// The merge of `upsertPages`, for a transaction that writes more than pages.
    static func upsert(_ pages: [GalleryPage], in db: Database) throws {
        guard !pages.isEmpty else { return }
        let statement = try db.makeStatement(sql: """
            INSERT INTO \(Schema.galleryPage)
                (gid, pageIndex, pageURL, imageURL, originalImageURL, previewURL, imageWidth, imageHeight)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (gid, pageIndex) DO UPDATE SET
                pageURL = coalesce(excluded.pageURL, pageURL),
                imageURL = coalesce(excluded.imageURL, imageURL),
                originalImageURL = coalesce(excluded.originalImageURL, originalImageURL),
                previewURL = coalesce(excluded.previewURL, previewURL),
                imageWidth = coalesce(excluded.imageWidth, imageWidth),
                imageHeight = coalesce(excluded.imageHeight, imageHeight)
            """)
        for page in pages {
            try statement.execute(arguments: page.databaseArguments)
        }
    }

    /// Every stored page of a gallery, by index.
    public func pages(gid: String) async throws -> [GalleryPage] {
        try await writer.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM \(Schema.galleryPage) WHERE gid = ? ORDER BY pageIndex",
                arguments: [gid]
            )
            .map(GalleryPage.init(row:))
        }
    }

    /// The stored pages of a gallery whose index is in `range`, by index.
    public func pages(gid: String, in range: ClosedRange<Int>) async throws -> [GalleryPage] {
        try await writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM \(Schema.galleryPage)
                WHERE gid = ? AND pageIndex BETWEEN ? AND ? ORDER BY pageIndex
                """,
                arguments: [gid, range.lowerBound, range.upperBound]
            )
            .map(GalleryPage.init(row:))
        }
    }

    public func deletePages(gid: String) async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM \(Schema.galleryPage) WHERE gid = ?", arguments: [gid])
        }
    }

    /// Deletes every stored page of every gallery (logout, clearing the image caches).
    public func deleteAllPages() async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM \(Schema.galleryPage)")
        }
    }

    /// Deletes the pages of every gallery not opened within `interval` before `now`, and pages
    /// with no `gallery` row at all. Image URLs expire on the site, so legacy dropped them
    /// after a week (`removeExpiredImageURLs`).
    public func deleteExpiredPages(notOpenedWithin interval: TimeInterval, now: Date = .now) async throws {
        let cutoff = now.addingTimeInterval(-interval)
        try await writer.write { db in
            try db.execute(
                sql: """
                DELETE FROM \(Schema.galleryPage) WHERE gid NOT IN
                    (SELECT gid FROM \(Schema.gallery) WHERE lastOpenDate >= ?)
                """,
                arguments: [cutoff]
            )
        }
    }
}
