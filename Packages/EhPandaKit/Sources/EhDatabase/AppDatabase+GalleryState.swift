import EhModels
import Foundation
import GRDB

// MARK: - Detail

extension AppDatabase {
    public func saveDetail(_ detail: GalleryDetail) async throws {
        try await writer.write { db in
            try GalleryDetailRecord(detail: detail).upsert(db)
        }
    }

    public func detail(gid: String) async throws -> GalleryDetail? {
        try await writer.read { db in
            try GalleryDetailRecord.fetchOne(db, key: gid)?.detail
        }
    }
}

// MARK: - State

extension AppDatabase {
    /// The stored per-gallery state, or `nil` if none was saved.
    ///
    /// Only `tags`, `readingProgress`, `previewConfig` and `comments` are filled; page URLs
    /// live in `galleryPage` and are read with ``pages(gid:)``.
    public func state(gid: String) async throws -> GalleryState? {
        try await writer.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT readingProgress, previewConfig, tags, comments
                FROM \(Schema.galleryState) WHERE gid = ?
                """,
                arguments: [gid]
            )
            guard let row else { return nil }
            return GalleryState(
                gid: gid,
                tags: JSONColumn.decode([GalleryTag].self, from: row["tags"]) ?? [],
                readingProgress: row["readingProgress"],
                previewConfig: JSONColumn.decode(PreviewConfig.self, from: row["previewConfig"]),
                comments: JSONColumn.decode([GalleryComment].self, from: row["comments"]) ?? []
            )
        }
    }

    public func updateReadingProgress(gid: String, progress: Int) async throws {
        try await updateStateColumn("readingProgress", gid: gid) { progress }
    }

    public func updateTags(gid: String, tags: [GalleryTag]) async throws {
        try await updateStateColumn("tags", gid: gid) { try JSONColumn.encode(tags) }
    }

    public func updateComments(gid: String, comments: [GalleryComment]) async throws {
        try await updateStateColumn("comments", gid: gid) { try JSONColumn.encode(comments) }
    }

    public func updatePreviewConfig(gid: String, config: PreviewConfig) async throws {
        try await updateStateColumn("previewConfig", gid: gid) { try JSONColumn.encode(config) }
    }

    /// Writes one column of `galleryState`, creating the row if needed, without touching the
    /// others. `column` is always a literal from this file, never user input. `value` runs
    /// inside the write so JSON encoding happens on GRDB's queue, not the caller's actor.
    private func updateStateColumn(
        _ column: String, gid: String,
        value: @escaping @Sendable () throws -> some DatabaseValueConvertible
    ) async throws {
        try await writer.write { db in
            let value = try value()
            try db.execute(
                sql: """
                INSERT INTO \(Schema.galleryState) (gid, \(column)) VALUES (?, ?)
                ON CONFLICT (gid) DO UPDATE SET \(column) = excluded.\(column)
                """,
                arguments: [gid, value]
            )
        }
    }
}
