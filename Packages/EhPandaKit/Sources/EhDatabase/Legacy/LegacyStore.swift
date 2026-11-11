import EhModels
import Foundation
import GRDB

/// Reads the Core Data store of EhPanda 2.x directly with SQLite, so users keep their history
/// and settings after upgrading. No Core Data model is needed.
///
/// Every step is separate and idempotent: check ``exists()``, ``readSnapshot()``, import it
/// with ``AppDatabase/importLegacyData(_:at:)``, and only once all of that succeeded,
/// ``deleteFiles()``.
public struct LegacyStore: Sendable {
    public static let fileName = "Model.sqlite"

    /// The store file: `Model.sqlite`. Core Data also keeps `-wal` and `-shm` beside it.
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The store legacy's `NSPersistentCloudKitContainer(name: "Model")` used, inside the
    /// app's `Library/Application Support` directory.
    public init(applicationSupportDirectory: URL) {
        self.init(url: applicationSupportDirectory.appendingPathComponent(Self.fileName))
    }

    var fileURLs: [URL] {
        [url, URL(fileURLWithPath: url.path + "-wal"), URL(fileURLWithPath: url.path + "-shm")]
    }

    @concurrent
    public func exists() async -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Reads everything worth keeping. Missing tables and columns are skipped; a file that
    /// is not an SQLite database throws.
    @concurrent
    public func readSnapshot() async throws -> LegacySnapshot {
        var configuration = Configuration()
        // Read-only never touches the user's only copy of their data. SQLite still reads
        // the WAL, creating `-shm` if needed, so writes not yet checkpointed are seen.
        configuration.readonly = true
        configuration.label = "EhPanda.LegacyStore"
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        defer { try? queue.close() }
        return try await queue.read { db in
            let history = try LegacyStoreReader.history(db)
            return LegacySnapshot(
                appEnvironment: try LegacyStoreReader.appEnvironment(db),
                history: history,
                readingProgress: try LegacyStoreReader.readingProgress(db, gids: Set(history.map(\.gid)))
            )
        }
    }

    /// Deletes the store and its `-wal` and `-shm` files. Files already gone are ignored.
    @concurrent
    public func deleteFiles() async throws {
        for fileURL in fileURLs {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch CocoaError.fileNoSuchFile {
                continue
            }
        }
    }
}

/// The queries against the legacy schema (Core Data model version 7 and older).
enum LegacyStoreReader {
    static func appEnvironment(_ db: Database) throws -> LegacySnapshot.AppEnvironment {
        guard try db.tableExists("ZAPPENVMO"),
              let row = try Row.fetchOne(db, sql: "SELECT * FROM ZAPPENVMO ORDER BY Z_PK LIMIT 1")
        else { return .init() }
        let legacy = LegacyRow(row: row)
        return .init(
            user: legacy.data("ZUSER"),
            setting: legacy.data("ZSETTING"),
            searchFilter: legacy.data("ZSEARCHFILTER"),
            globalFilter: legacy.data("ZGLOBALFILTER"),
            watchedFilter: legacy.data("ZWATCHEDFILTER"),
            tagTranslator: legacy.data("ZTAGTRANSLATOR"),
            historyKeywords: legacy.data("ZHISTORYKEYWORDS"),
            quickSearchWords: legacy.data("ZQUICKSEARCHWORDS")
        )
    }

    /// Galleries with a `lastOpenDate`, newest first, one per gid.
    static func history(_ db: Database) throws -> [Gallery] {
        guard try db.tableExists("ZGALLERYMO"),
              try db.columns(in: "ZGALLERYMO").contains(where: { $0.name == "ZLASTOPENDATE" })
        else { return [] }
        let rows = try Row.fetchCursor(
            db, sql: "SELECT * FROM ZGALLERYMO WHERE ZLASTOPENDATE IS NOT NULL ORDER BY ZLASTOPENDATE DESC"
        )
        var seen = Set<String>()
        var galleries = [Gallery]()
        while let row = try rows.next() {
            guard let gallery = gallery(LegacyRow(row: row)), seen.insert(gallery.gid).inserted
            else { continue }
            galleries.append(gallery)
        }
        return galleries
    }

    private static func gallery(_ row: LegacyRow) -> Gallery? {
        guard let gid = row.string("ZGID"), !gid.isEmpty,
              let lastOpenDate = row.date("ZLASTOPENDATE")
        else { return nil }
        return Gallery(
            gid: gid,
            token: row.string("ZTOKEN") ?? "",
            title: row.string("ZTITLE") ?? "",
            rating: Float(row.double("ZRATING") ?? 0),
            tags: row.data("ZTAGS").flatMap { try? JSONDecoder().decode([GalleryTag].self, from: $0) } ?? [],
            category: row.string("ZCATEGORY").flatMap(Category.init(rawValue:)) ?? .private,
            uploader: row.string("ZUPLOADER"),
            pageCount: row.int("ZPAGECOUNT") ?? 0,
            postedDate: row.date("ZPOSTEDDATE") ?? LegacyDate.date(fromCoreDataTimestamp: 0),
            coverURL: row.url("ZCOVERURL"),
            galleryURL: row.url("ZGALLERYURL"),
            lastOpenDate: lastOpenDate
        )
    }

    static func readingProgress(_ db: Database, gids: Set<String>) throws -> [String: Int] {
        guard !gids.isEmpty, try db.tableExists("ZGALLERYSTATEMO") else { return [:] }
        let columns = try Set(db.columns(in: "ZGALLERYSTATEMO").map(\.name))
        guard columns.contains("ZGID"), columns.contains("ZREADINGPROGRESS") else { return [:] }
        let rows = try Row.fetchCursor(db, sql: "SELECT ZGID, ZREADINGPROGRESS FROM ZGALLERYSTATEMO")
        var progress = [String: Int]()
        while let row = try rows.next() {
            let legacy = LegacyRow(row: row)
            guard let gid = legacy.string("ZGID"), gids.contains(gid),
                  let value = legacy.int("ZREADINGPROGRESS"), value > 0
            else { continue }
            // Duplicate state rows are possible in Core Data; keep the furthest progress.
            progress[gid] = max(progress[gid] ?? 0, value)
        }
        return progress
    }
}
