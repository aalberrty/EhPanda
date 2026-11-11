import EhModels
import Foundation
import GRDB

// MARK: - Legacy import

extension AppDatabase {
    /// Imports what this database owns from a legacy snapshot, in one transaction: history
    /// galleries, their reading progress, search history and quick-search words.
    ///
    /// Settings, filters, the user and the tag translator in `snapshot.appEnvironment` are not
    /// touched; they belong to the caller. Importing again is harmless: data already in this
    /// database wins, a gallery's `lastOpenDate` only moves forward, and nothing is duplicated.
    /// Undecodable blobs are skipped.
    ///
    /// - Parameter date: imported search keywords are dated just before it, oldest first.
    public func importLegacyData(_ snapshot: LegacySnapshot, at date: Date = .now) async throws {
        try await writer.write { db in
            try Self.importHistory(snapshot.history, db)
            try Self.importReadingProgress(snapshot.readingProgress, db)
            if let blob = snapshot.appEnvironment.historyKeywords,
               let keywords = try? JSONDecoder().decode([String].self, from: blob) {
                try Self.importSearchKeywords(keywords, before: date, db)
            }
            if let blob = snapshot.appEnvironment.quickSearchWords,
               let words = try? JSONDecoder().decode([QuickSearchWord].self, from: blob) {
                try Self.importQuickSearchWords(words, db)
            }
        }
    }

    private static func importHistory(_ galleries: [Gallery], _ db: Database) throws {
        let statement = try db.makeStatement(sql: """
            INSERT INTO \(Schema.gallery)
                (gid, token, title, rating, category, uploader, pageCount, postedDate,
                 coverURL, galleryURL, tags, lastOpenDate)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (gid) DO UPDATE SET lastOpenDate = max(lastOpenDate, excluded.lastOpenDate)
            """)
        for gallery in galleries {
            guard let lastOpenDate = gallery.lastOpenDate else { continue }
            let record = try GalleryRecord(gallery: gallery, lastOpenDate: lastOpenDate)
            try statement.execute(arguments: [
                record.gid, record.token, record.title, record.rating, record.category,
                record.uploader, record.pageCount, record.postedDate, record.coverURL,
                record.galleryURL, record.tags, record.lastOpenDate
            ])
        }
    }

    private static func importReadingProgress(_ progress: [String: Int], _ db: Database) throws {
        let statement = try db.makeStatement(sql: """
            INSERT INTO \(Schema.galleryState) (gid, readingProgress) VALUES (?, ?)
            ON CONFLICT (gid) DO NOTHING
            """)
        for (gid, value) in progress {
            try statement.execute(arguments: [gid, value])
        }
    }

    /// `keywords` is legacy's array, oldest first. Keywords already stored (ignoring case)
    /// keep their newer date.
    private static func importSearchKeywords(_ keywords: [String], before date: Date, _ db: Database) throws {
        var stored = try String.fetchAll(db, sql: "SELECT keyword FROM \(Schema.searchHistory)")
        let insert = try db.makeStatement(
            sql: "INSERT INTO \(Schema.searchHistory) (keyword, lastUsedAt) VALUES (?, ?)"
        )
        for (offset, keyword) in keywords.enumerated() where !keyword.isEmpty {
            guard !stored.contains(where: { $0.caseInsensitiveCompare(keyword) == .orderedSame })
            else { continue }
            let usedAt = date.addingTimeInterval(-Double(keywords.count - offset) / 1000)
            try insert.execute(arguments: [keyword, usedAt])
            stored.append(keyword)
        }
        try trimSearchHistory(db)
    }

    private static func importQuickSearchWords(_ words: [QuickSearchWord], _ db: Database) throws {
        let insert = try db.makeStatement(sql: """
            INSERT INTO \(Schema.quickSearchWord) (id, name, content, position)
            VALUES (?, ?, ?, (SELECT coalesce(max(position), -1) + 1 FROM \(Schema.quickSearchWord)))
            ON CONFLICT (id) DO NOTHING
            """)
        for word in words {
            try insert.execute(arguments: [word.id.uuidString, word.name, word.content])
        }
    }
}
