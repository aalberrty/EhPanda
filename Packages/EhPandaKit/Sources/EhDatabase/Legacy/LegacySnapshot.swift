import EhModels
import Foundation

/// What the app keeps from the legacy Core Data store.
public struct LegacySnapshot: Sendable {
    /// The raw JSON blobs of the legacy `AppEnvMO` row. Any of them may be `nil`, meaning
    /// the user never changed that part (legacy then used the type's default).
    public struct AppEnvironment: Sendable, Equatable {
        public var user: Data?
        public var setting: Data?
        public var searchFilter: Data?
        public var globalFilter: Data?
        public var watchedFilter: Data?
        public var tagTranslator: Data?
        public var historyKeywords: Data?
        public var quickSearchWords: Data?

        public init(
            user: Data? = nil, setting: Data? = nil, searchFilter: Data? = nil,
            globalFilter: Data? = nil, watchedFilter: Data? = nil, tagTranslator: Data? = nil,
            historyKeywords: Data? = nil, quickSearchWords: Data? = nil
        ) {
            self.user = user
            self.setting = setting
            self.searchFilter = searchFilter
            self.globalFilter = globalFilter
            self.watchedFilter = watchedFilter
            self.tagTranslator = tagTranslator
            self.historyKeywords = historyKeywords
            self.quickSearchWords = quickSearchWords
        }
    }

    public var appEnvironment: AppEnvironment
    /// Galleries the user opened, most recent first, each with `lastOpenDate` set.
    public var history: [Gallery]
    /// Reading progress of the galleries in `history`, by gid. Galleries without stored
    /// progress are absent.
    public var readingProgress: [String: Int]

    public init(
        appEnvironment: AppEnvironment = .init(),
        history: [Gallery] = [],
        readingProgress: [String: Int] = [:]
    ) {
        self.appEnvironment = appEnvironment
        self.history = history
        self.readingProgress = readingProgress
    }
}
