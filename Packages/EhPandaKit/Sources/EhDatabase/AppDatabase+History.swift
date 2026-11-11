import EhModels
import Foundation
import GRDB

// MARK: - History

extension AppDatabase {
    /// Records that `gallery` was opened: stores its latest list data and sets `lastOpenDate`.
    public func recordOpened(_ gallery: Gallery, at date: Date = .now) async throws {
        try await writer.write { db in
            try GalleryRecord(gallery: gallery, lastOpenDate: date).upsert(db)
        }
    }

    /// The stored gallery with `gid`, whose `lastOpenDate` is set; `nil` if it was never opened.
    public func gallery(gid: String) async throws -> Gallery? {
        try await writer.read { db in
            try GalleryRecord.fetchOne(db, key: gid)?.gallery
        }
    }

    /// Opened galleries, most recently opened first. Emits the current value at once and again
    /// after every committed change to `gallery`.
    public func observeHistory(limit: Int? = nil) -> some AsyncSequence<[Gallery], any Error> & Sendable {
        let observation = ValueObservation.tracking { db in
            var request = GalleryRecord.order(GalleryRecord.Columns.lastOpenDate.desc)
            if let limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db).map(\.gallery)
        }
        // `.task` delivers values from a task rather than the main queue.
        return observation.values(in: writer, scheduling: .task)
    }

    /// Deletes every gallery, detail, state and page row.
    ///
    /// This is a privacy feature, so the content must not stay recoverable on disk:
    /// `secure_delete` zeroes the freed pages in the database file, and the write-ahead log,
    /// which still holds the rows' earlier content, is checkpointed and truncated afterwards.
    public func clearHistory() async throws {
        try await writer.write { db in
            try db.execute(sql: "PRAGMA secure_delete = ON")
            defer { try? db.execute(sql: "PRAGMA secure_delete = OFF") }
            for table in [Schema.gallery, Schema.galleryDetail, Schema.galleryState, Schema.galleryPage] {
                try db.execute(sql: "DELETE FROM \(table)")
            }
        }
        // A checkpoint cannot run inside a transaction. It is a no-op for an in-memory database.
        try await writer.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }
}
