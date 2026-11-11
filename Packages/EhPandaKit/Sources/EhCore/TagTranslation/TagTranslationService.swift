import Dependencies
import EhDatabase
import EhModels
import Foundation
import Observation

/// Owns the tag translation database: the in-memory table cells translate from, downloads,
/// custom translations, suggestions and the one-time legacy import.
///
/// Translating a tag is a synchronous dictionary lookup. Everything else (database access,
/// Markdown, OpenCC, ranking) runs off the main actor; results are published in one assignment.
@MainActor @Observable
public final class TagTranslationService {
    /// Display data by lookup key (namespace raw value + tag, e.g. `femalebig breasts`).
    public internal(set) var translations: [String: TagTranslationDisplay] = [:]
    public internal(set) var loadingState: TagTranslationLoadingState = .idle
    /// The stored table has been read from the database at least once.
    public internal(set) var isLoaded = false

    /// Observed by hand so the nonisolated initializer can set it from `UserDefaults`.
    public internal(set) var metadata: TagTranslationMetadata {
        get {
            access(keyPath: \.metadata)
            return storedMetadata
        }
        set {
            withMutation(keyPath: \.metadata) { storedMetadata = newValue }
        }
    }

    @ObservationIgnored let databaseProvider: AppDatabaseProvider
    @ObservationIgnored let remote: TagTranslationRemote
    @ObservationIgnored private var storedMetadata: TagTranslationMetadata
    @ObservationIgnored let defaults: SendableUserDefaults
    @ObservationIgnored let preferredLanguages: @Sendable () -> [String]
    @ObservationIgnored @Dependency(\.appLogger) var logger
    /// The in-flight download, shared by concurrent `fetchUpdates()` calls.
    @ObservationIgnored var updateTask: Task<Void, Never>?
    /// The last queued change to the stored translations; each change waits for the previous.
    @ObservationIgnored var mutationTail: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// - Parameter preferredLanguages: the user's preferred languages, most preferred first
    ///   (`Locale.preferredLanguages` in the app). Read on every update.
    public nonisolated init(
        database: AppDatabaseProvider,
        remote: TagTranslationRemote,
        defaults: UserDefaults,
        preferredLanguages: @escaping @Sendable () -> [String] = { Locale.preferredLanguages }
    ) {
        databaseProvider = database
        self.remote = remote
        self.defaults = SendableUserDefaults(defaults)
        self.preferredLanguages = preferredLanguages
        storedMetadata = TagTranslationMetadata(defaults: defaults)
    }

    public var language: TranslatableLanguage? { metadata.language }
    public var updatedDate: Date { metadata.updatedDate }
    public var hasCustomTranslations: Bool { metadata.hasCustomTranslations }
    /// Legacy's "translator is empty", which hides the translation toggles in settings.
    public var isEmpty: Bool { translations.isEmpty }

    // MARK: Lookup

    /// The lookup key of a tag: namespace raw value + tag.
    public nonisolated static func key(namespace: TagNamespace, tag: String) -> String {
        namespace.rawValue + tag
    }

    /// Display text and image for a lookup key. `nil` when the database has an entry for the
    /// tag but no name for it (most Japanese and all English entries only carry a
    /// description), so callers fall back to the original tag instead of showing nothing.
    public func display(forKey key: String) -> TagTranslationDisplay? {
        guard let display = translations[key],
              !display.displayValue.isEmpty || display.valueImageURL != nil
        else { return nil }
        return display
    }

    /// The tag detail sheet's content for each key that has a description, computed off the
    /// main actor from one database read. Keys without a translation or description are absent.
    public func details(forKeys keys: [String]) async -> [String: TagDetail] {
        guard let stored = try? await database().tagTranslations(keys: keys) else { return [:] }
        return await Self.makeDetails(stored)
    }

    @concurrent
    private nonisolated static func makeDetails(_ stored: [String: StoredTagTranslation]) async -> [String: TagDetail] {
        stored.compactMapValues(TagTranslationPreparation.detail(of:))
    }

    // MARK: Loading

    /// Reads the stored table into memory. Call once at launch; later calls return at once.
    public func load() async {
        if let loadTask { return await loadTask.value }
        let task = Task { await reloadTranslations() }
        loadTask = task
        await task.value
    }

    func reloadTranslations() async {
        do {
            translations = try await database().tagTranslationLookup()
            isLoaded = true
        } catch {
            logger.error("Failed to load tag translations: \(error)", category: Self.logCategory)
        }
    }

    func database() async throws -> AppDatabase {
        try await databaseProvider.value
    }

    nonisolated static let logCategory = "TagTranslation"
}

// MARK: Dependency

extension TagTranslationService: DependencyKey {
    public nonisolated static var liveValue: TagTranslationService {
        @Dependency(\.tagTranslationRemote) var remote
        // Launch installs the database after this service may first be referenced (the shell
        // puts it in the environment), so `\.database` is read on first use, not here.
        let database = AppDatabaseProvider {
            @Dependency(\.database) var database
            return database
        }
        return TagTranslationService(database: database, remote: remote, defaults: .standard)
    }

    /// An in-memory database, an unimplemented remote and private defaults, per test.
    public nonisolated static var testValue: TagTranslationService {
        @Dependency(\.database) var database
        @Dependency(\.tagTranslationRemote) var remote
        return TagTranslationService(
            database: AppDatabaseProvider(database), remote: remote, defaults: .ephemeral(),
            preferredLanguages: { ["en"] }
        )
    }
}

extension DependencyValues {
    public var tagTranslationService: TagTranslationService {
        get { self[TagTranslationService.self] }
        set { self[TagTranslationService.self] = newValue }
    }
}

/// `UserDefaults` is documented as thread-safe but not marked `Sendable`; this box lets the
/// service's nonisolated initializer keep it. It is only used from the main actor.
struct SendableUserDefaults: @unchecked Sendable {
    let defaults: UserDefaults

    init(_ defaults: UserDefaults) { self.defaults = defaults }
}

extension UserDefaults {
    /// A new, empty suite that nothing else reads, for tests and previews.
    static func ephemeral() -> UserDefaults {
        let name = "EhPanda.ephemeral.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
