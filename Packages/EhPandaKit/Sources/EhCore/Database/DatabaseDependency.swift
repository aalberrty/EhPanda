import Dependencies
import EhDatabase
import Foundation
import Synchronization

/// The on-disk database of the running app.
///
/// Opening it can fail (and the user can then choose to rebuild it), so it is opened by the
/// launch sequence rather than lazily. Launch installs it here before any feature screen
/// exists; `\.database` then hands it out.
public enum LiveDatabase {
    private static let installed = Mutex<AppDatabase?>(nil)

    /// Where the app keeps its database file.
    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "EhPanda/EhPanda.sqlite")
    }

    public static func install(_ database: AppDatabase) {
        installed.withLock { $0 = database }
    }

    static var current: AppDatabase? {
        installed.withLock { $0 }
    }
}

private enum DatabaseKey: DependencyKey {
    static var liveValue: AppDatabase {
        guard let database = LiveDatabase.current else {
            preconditionFailure(
                "\\.database was read before launch installed it with LiveDatabase.install(_:)."
            )
        }
        return database
    }

    // An empty in-memory database: isolated per test, so a test that does not care about
    // persistence needs no setup, and one that does seeds its own.
    static var testValue: AppDatabase { makeInMemory() }
    static var previewValue: AppDatabase { makeInMemory() }

    private static func makeInMemory() -> AppDatabase {
        do {
            return try AppDatabase.makeInMemory()
        } catch {
            fatalError("Could not create an in-memory database: \(error)")
        }
    }
}

extension DependencyValues {
    /// The app's SQLite database.
    public var database: AppDatabase {
        get { self[DatabaseKey.self] }
        set { self[DatabaseKey.self] = newValue }
    }
}
