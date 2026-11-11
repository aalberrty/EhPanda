import EhModels
import Foundation
import GRDB

/// What the reader needs to open a gallery where it was left.
public struct ReadingState: Sendable, Equatable {
    /// The 1-based page last read, or 0.
    public var readingProgress: Int
    public var previewConfig: PreviewConfig?

    public init(readingProgress: Int, previewConfig: PreviewConfig?) {
        self.readingProgress = readingProgress
        self.previewConfig = previewConfig
    }
}

// MARK: - Detail

extension AppDatabase {
    /// Stores a freshly fetched detail page in one transaction: the detail, the tags and
    /// comments, the preview layout when the page showed one, and the URLs `state` carries for
    /// its pages (the first preview page's thumbnails and viewer links), merged like
    /// `upsertPages`. The stored reading progress is left as it is.
    public func saveDetail(_ detail: GalleryDetail, state: GalleryState) async throws {
        try await writer.write { db in
            try GalleryDetailRecord(detail: detail).upsert(db)
            try db.execute(
                sql: """
                INSERT INTO \(Schema.galleryState) (gid, tags, comments, previewConfig) VALUES (?, ?, ?, ?)
                ON CONFLICT (gid) DO UPDATE SET
                    tags = excluded.tags,
                    comments = excluded.comments,
                    previewConfig = coalesce(excluded.previewConfig, previewConfig)
                """,
                arguments: [
                    detail.gid,
                    try JSONColumn.encode(state.tags),
                    try JSONColumn.encode(state.comments),
                    try state.previewConfig.map { try JSONColumn.encode($0) }
                ]
            )
            try Self.upsert(Self.pages(of: state, gid: detail.gid), in: db)
        }
    }

    public func detail(gid: String) async throws -> GalleryDetail? {
        try await writer.read { db in
            try GalleryDetailRecord.fetchOne(db, key: gid)?.detail
        }
    }

    private static func pages(of state: GalleryState, gid: String) -> [GalleryPage] {
        let indices = Set(state.previewURLs.keys)
            .union(state.thumbnailURLs.keys)
            .union(state.imageURLs.keys)
            .union(state.originalImageURLs.keys)
        return indices.sorted().map { index in
            GalleryPage(
                gid: gid, index: index,
                pageURL: state.thumbnailURLs[index], imageURL: state.imageURLs[index],
                originalImageURL: state.originalImageURLs[index], previewURL: state.previewURLs[index]
            )
        }
    }
}

// MARK: - State

extension AppDatabase {
    /// The stored per-gallery state, or `nil` if none was saved.
    ///
    /// Only `tags`, `readingProgress`, `previewConfig` and `comments` are filled; page URLs
    /// live in `galleryPage` and are read with ``pages(gid:)``. Decodes every tag and comment:
    /// a caller that needs neither reads ``readingState(gid:)``.
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

    /// The reading progress and the preview layout, without reading the tags and comments
    /// stored next to them. `nil` if nothing was saved for the gallery.
    public func readingState(gid: String) async throws -> ReadingState? {
        try await writer.read { db in
            let row = try Row.fetchOne(
                db,
                sql: "SELECT readingProgress, previewConfig FROM \(Schema.galleryState) WHERE gid = ?",
                arguments: [gid]
            )
            guard let row else { return nil }
            return ReadingState(
                readingProgress: row["readingProgress"],
                previewConfig: JSONColumn.decode(PreviewConfig.self, from: row["previewConfig"])
            )
        }
    }

    /// Writes the reading progress, creating the row if needed, without touching the rest.
    public func updateReadingProgress(gid: String, progress: Int) async throws {
        try await writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO \(Schema.galleryState) (gid, readingProgress) VALUES (?, ?)
                ON CONFLICT (gid) DO UPDATE SET readingProgress = excluded.readingProgress
                """,
                arguments: [gid, progress]
            )
        }
    }
}
