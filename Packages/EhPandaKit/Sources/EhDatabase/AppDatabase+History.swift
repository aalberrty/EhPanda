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

    /// The most recently opened galleries whose title contains `titleFilter` (ignoring case;
    /// every gallery when it is empty), at most `limit` of them. Emits at once and again after
    /// every committed change to `gallery`.
    ///
    /// The filter is part of the query, so it searches the whole history while only `limit`
    /// rows are read and decoded.
    public func observeHistory(
        limit: Int, titleFilter: String
    ) -> some AsyncSequence<HistoryPage, any Error> & Sendable {
        let keyword = titleFilter.lowercased()
        let observation = ValueObservation.tracking { db in
            var request = GalleryRecord.order(GalleryRecord.Columns.lastOpenDate.desc)
            if !keyword.isEmpty {
                // `swiftLowercaseString` is GRDB's built-in Unicode-aware lowercasing.
                request = request.filter(literal: "instr(\(GalleryRecord.Columns.title.lowercased), \(keyword)) > 0")
            }
            // One row more than asked tells whether there are more.
            let records = try request.limit(limit + 1).fetchAll(db)
            let isHistoryEmpty = keyword.isEmpty ? records.isEmpty : try GalleryRecord.limit(1).fetchCount(db) == 0
            return HistoryPage(
                galleries: records.prefix(limit).map(\.gallery),
                hasMore: records.count > limit,
                isHistoryEmpty: isHistoryEmpty
            )
        }
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

/// One read of the history: the galleries asked for and what the screen needs around them.
public struct HistoryPage: Sendable, Equatable {
    public let galleries: [Gallery]
    /// Whether more galleries match than were read.
    public let hasMore: Bool
    /// Whether the history holds no gallery at all, whatever the filter.
    public let isHistoryEmpty: Bool

    public init(galleries: [Gallery], hasMore: Bool, isHistoryEmpty: Bool) {
        self.galleries = galleries
        self.hasMore = hasMore
        self.isHistoryEmpty = isHistoryEmpty
    }
}
