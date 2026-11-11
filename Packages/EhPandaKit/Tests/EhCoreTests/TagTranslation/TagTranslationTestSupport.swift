import EhDatabase
import EhModels
import EhTestSupport
import Foundation
import Synchronization
@testable import EhCore

/// A scripted remote that counts calls and can hold the release check until released.
final class StubTagTranslationRemote: Sendable {
    struct State {
        var releaseDates: [TranslatableLanguage: Date] = [:]
        var databases: [TranslatableLanguage: [String: TagTranslation]] = [:]
        var downloadError: (any Error)?
        var releaseChecks = [(TranslatableLanguage, Date)]()
        var downloads = [TranslatableLanguage]()
        var gate: AsyncStream<Void>?
    }

    let state = Mutex(State())

    var remote: TagTranslationRemote {
        TagTranslationRemote(
            latestReleaseDate: { [self] language, storedDate in
                let (date, gate) = state.withLock { state in
                    state.releaseChecks.append((language, storedDate))
                    return (state.releaseDates[language], state.gate)
                }
                if let gate { for await _ in gate { break } }
                guard let date else { throw URLError(.notConnectedToInternet) }
                return date
            },
            downloadDatabase: { [self] language in
                let (database, error) = state.withLock { state in
                    state.downloads.append(language)
                    return (state.databases[language] ?? [:], state.downloadError)
                }
                if let error { throw error }
                return database
            }
        )
    }

    /// Makes the release check wait until the returned continuation finishes.
    func holdReleaseCheck() -> AsyncStream<Void>.Continuation {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        state.withLock { $0.gate = stream }
        return continuation
    }

    func publish(_ language: TranslatableLanguage, date: Date, translations: [String: TagTranslation]) {
        state.withLock { state in
            state.releaseDates[language] = date
            state.databases[language] = translations
        }
    }

    var downloadCount: Int { state.withLock { $0.downloads.count } }
}

final class PreferredLanguages: Sendable {
    private let languages: Mutex<[String]>

    init(_ languages: [String]) { self.languages = Mutex(languages) }

    func set(_ newValue: [String]) { languages.withLock { $0 = newValue } }
    func get() -> [String] { languages.withLock { $0 } }
}

struct ServiceHarness {
    let service: TagTranslationService
    let database: AppDatabase
    let remote: StubTagTranslationRemote
    let languages: PreferredLanguages
    let defaults: UserDefaults

    @MainActor
    static func make(languages: [String] = ["zh-Hans-CN"], defaults: UserDefaults = .ephemeral()) async throws -> Self {
        let database = try await TestDatabase.inMemory()
        let remote = StubTagTranslationRemote()
        let preferred = PreferredLanguages(languages)
        let service = TagTranslationService(
            database: AppDatabaseProvider(database), remote: remote.remote, defaults: defaults,
            preferredLanguages: { preferred.get() }
        )
        return Self(service: service, database: database, remote: remote, languages: preferred, defaults: defaults)
    }
}

enum Samples {
    static let releaseDate = Date(timeIntervalSince1970: 1_700_000_000)

    static func translation(
        _ namespace: TagNamespace, _ key: String, _ value: String, description: String? = nil
    ) -> TagTranslation {
        TagTranslation(namespace: namespace, key: key, value: value, description: description)
    }

    static func keyed(_ translations: [TagTranslation]) -> [String: TagTranslation] {
        Dictionary(uniqueKeysWithValues: translations.map { ($0.namespace.rawValue + $0.key, $0) })
    }

    static let chinese = keyed([
        translation(.female, "big breasts", "巨乳", description: "乳房较大。![图](https://ehgt.org/a.jpg)"),
        translation(.female, "lolicon", "萝莉"),
        translation(.parody, "touhou project", "![阴阳玉图标](https://ehgt.org/touhou.webp)东方Project")
    ])

    /// A database file as the user would pick it (`db.raw.json`).
    static func databaseFile(_ entries: [String: [String: String]]) -> Data {
        let response = EhTagTranslationDatabaseResponse(data: entries.map { namespace, names in
            .init(namespace: namespace, data: names.mapValues { .init(name: $0, intro: "", links: "") })
        })
        return (try? JSONEncoder().encode(response)) ?? Data()
    }
}
