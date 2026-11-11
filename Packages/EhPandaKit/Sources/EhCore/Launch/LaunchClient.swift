import Dependencies
import EhDatabase
import EhNetworking
import Foundation

/// The launch work that touches disk, as replaceable steps. `AppModel` decides the order.
public struct LaunchClient: Sendable {
    /// Cookie housekeeping (legacy `AppDelegateReducer.onLaunchFinish`). Runs off the main actor.
    public var prepareCookies: @Sendable () async -> Void
    /// Opens, creating or migrating it if needed, the app database.
    public var openDatabase: @Sendable () async throws -> AppDatabase
    /// Deletes the database files so the next open starts empty ("Drop the database").
    public var dropDatabase: @Sendable () async throws -> Void
    /// Makes the database available to everything that reads `\.database`.
    public var installDatabase: @Sendable (AppDatabase) -> Void
    /// The one-time import of the old app's data into the database and the stores.
    public var importLegacyData: @MainActor @Sendable (AppDatabase) async -> LegacyImportReport

    public init(
        prepareCookies: @escaping @Sendable () async -> Void,
        openDatabase: @escaping @Sendable () async throws -> AppDatabase,
        dropDatabase: @escaping @Sendable () async throws -> Void,
        installDatabase: @escaping @Sendable (AppDatabase) -> Void,
        importLegacyData: @escaping @MainActor @Sendable (AppDatabase) async -> LegacyImportReport
    ) {
        self.prepareCookies = prepareCookies
        self.openDatabase = openDatabase
        self.dropDatabase = dropDatabase
        self.installDatabase = installDatabase
        self.importLegacyData = importLegacyData
    }
}

extension LaunchClient: DependencyKey {
    public static let liveValue = LaunchClient(
        prepareCookies: {
            @Dependency(\.cookieStore) var cookies
            await CookieHousekeeping.run(cookies)
        },
        openDatabase: { try await AppDatabase.open(at: LiveDatabase.defaultURL) },
        dropDatabase: {
            try await DatabaseFiles.delete(at: LiveDatabase.defaultURL)
            // The rebuilt database is empty, so the history import may run again if the old
            // store is still there.
            LegacyImportLedger(defaults: .standard).forget(.database)
        },
        installDatabase: { LiveDatabase.install($0) },
        importLegacyData: { database in
            @Dependency(\.settings) var settings
            @Dependency(\.filterStore) var filters
            @Dependency(\.userStore) var user
            let migrator = LegacyMigrator(
                store: LegacyStore(applicationSupportDirectory: .applicationSupportDirectory),
                defaults: .standard,
                importTagTranslations: LiveLegacyTagTranslations.importBlob
            )
            return await migrator.run(database: database, settings: settings, filters: filters, user: user)
        }
    )

    public static let testValue = LaunchClient(
        prepareCookies: unimplemented("LaunchClient.prepareCookies"),
        openDatabase: unimplemented("LaunchClient.openDatabase"),
        dropDatabase: unimplemented("LaunchClient.dropDatabase"),
        installDatabase: unimplemented("LaunchClient.installDatabase"),
        importLegacyData: unimplemented("LaunchClient.importLegacyData", placeholder: .nothingToImport)
    )

    /// An in-memory database and nothing to import.
    public static let previewValue = LaunchClient(
        prepareCookies: {},
        openDatabase: { try await AppDatabase.inMemory() },
        dropDatabase: {},
        installDatabase: { _ in },
        importLegacyData: { _ in .nothingToImport }
    )
}

extension DependencyValues {
    public var launchClient: LaunchClient {
        get { self[LaunchClient.self] }
        set { self[LaunchClient.self] = newValue }
    }
}

/// Cookie fixes applied on every launch.
enum CookieHousekeeping {
    /// Legacy ran these in the order remove `yay`, sync ExHentai cookies, ignore offensive,
    /// fill the other host. Filling the other host first means credentials copied from
    /// e-hentai.org reach s.exhentai.org in the same launch instead of the next one.
    @concurrent
    static func run(_ cookies: CookieStore) async {
        cookies.removeYay()
        cookies.fulfillAnotherHostField()
        cookies.syncExCookies()
        cookies.ignoreOffensive()
    }
}

/// The SQLite files of a database.
enum DatabaseFiles {
    /// Deletes the database and its `-wal` and `-shm` files. Files already gone are ignored.
    @concurrent
    static func delete(at url: URL) async throws {
        for suffix in ["", "-wal", "-shm"] {
            do {
                try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            } catch CocoaError.fileNoSuchFile {
                continue
            }
        }
    }
}
