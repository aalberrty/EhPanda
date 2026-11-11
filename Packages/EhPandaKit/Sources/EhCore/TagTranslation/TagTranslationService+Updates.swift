import EhDatabase
import EhModels
import Foundation

// MARK: Downloads

extension TagTranslationService {
    /// Legacy `fetchTagTranslator`: downloads the database for the user's language when a newer
    /// release exists. Call at launch when the tags extension is on and when the user turns it
    /// on. Does nothing while custom translations are in use or when the most preferred
    /// language is not translatable. Concurrent calls share one download.
    ///
    /// When the language changed since the last download, the stored translations are dropped
    /// first, as legacy did. A failed download leaves the stored translations untouched.
    public func fetchUpdates() async {
        if let updateTask { return await updateTask.value }
        guard !metadata.hasCustomTranslations,
              let language = preferredLanguages().first.flatMap(TranslatableLanguage.matching(preferredLanguage:))
        else { return }
        let task = Task { await serialized { await performUpdate(language: language) } }
        updateTask = task
        await task.value
        if updateTask == task { updateTask = nil }
    }

    private func performUpdate(language: TranslatableLanguage) async {
        await load()
        // Custom translations may have been imported while this update waited.
        guard !metadata.hasCustomTranslations, !Task.isCancelled else { return }
        loadingState = .loading
        do {
            if metadata.language != language {
                try await withDatabaseError { try await database().deleteAllTagTranslations() }
                translations = [:]
                setMetadata(TagTranslationMetadata(language: language))
            }
            let storedDate = metadata.updatedDate
            let latestDate = try await remote.latestReleaseDate(language, storedDate)
            guard latestDate > storedDate else { throw TagTranslationError.noUpdates }
            let downloaded = try await remote.downloadDatabase(language)
            guard !downloaded.isEmpty else { throw TagTranslationError.parseFailed }
            let prepared = await Self.prepare(
                downloaded,
                traditionalChineseFor: language == .traditionalChinese ? preferredLanguages() : nil
            )
            try Task.checkCancellation()
            try await withDatabaseError { try await database().replaceTagTranslations(prepared.rows) }
            translations = prepared.table
            setMetadata(TagTranslationMetadata(language: language, updatedDate: latestDate))
            loadingState = .idle
        } catch {
            loadingState = Self.loadingState(after: error)
        }
    }

    /// Cancels an in-flight download; it ends without changing what is stored.
    func cancelUpdate() {
        updateTask?.cancel()
    }
}

// MARK: Custom translations and legacy import

extension TagTranslationService {
    /// Imports a database file the user picked (the `db.raw.json` format), replacing every
    /// stored translation and stopping downloads until the custom translations are removed.
    /// Failures are reported through `loadingState`, as legacy did.
    public func importCustomTranslations(from data: Data) async {
        cancelUpdate()
        await serialized {
            await load()
            loadingState = .loading
            do {
                let decoded = try await Self.decodeDatabaseFile(data)
                let prepared = await Self.prepare(decoded, traditionalChineseFor: nil)
                try await withDatabaseError { try await database().replaceTagTranslations(prepared.rows) }
                translations = prepared.table
                setMetadata(TagTranslationMetadata(hasCustomTranslations: true))
                loadingState = .idle
            } catch {
                loadingState = Self.loadingState(after: error)
            }
        }
    }

    /// Drops the custom translations. As in legacy, nothing is downloaded until the next
    /// `fetchUpdates()`.
    public func removeCustomTranslations() async {
        await serialized {
            await load()
            guard metadata.hasCustomTranslations else { return }
            do {
                try await database().deleteAllTagTranslations()
                translations = [:]
                setMetadata(TagTranslationMetadata(
                    language: metadata.language, updatedDate: metadata.updatedDate, hasCustomTranslations: false
                ))
            } catch {
                logger.error("Failed to remove custom tag translations: \(error)", category: Self.logCategory)
            }
        }
    }

    /// Stores the tag translator of the legacy Core Data store (its raw JSON blob) with its
    /// metadata, replacing what is stored. Does nothing for `nil` or a blob that does not
    /// decode, since trying again could not help.
    ///
    /// - Throws: When the translations could not be written, so the caller keeps the legacy
    ///   store and tries again on the next launch instead of losing them.
    public func importLegacyTranslator(_ data: Data?) async throws {
        guard let data else { return }
        var failure: (any Error)?
        await serialized {
            await load()
            guard let translator = await Self.decodeLegacyTranslator(data) else {
                logger.warning("Skipped an unreadable legacy tag translator", category: Self.logCategory)
                return
            }
            let prepared = await Self.prepare(translator.translations, traditionalChineseFor: nil)
            do {
                try await database().replaceTagTranslations(prepared.rows)
                translations = prepared.table
                setMetadata(TagTranslationMetadata(
                    language: translator.language, updatedDate: translator.updatedDate,
                    hasCustomTranslations: translator.hasCustomTranslations
                ))
            } catch {
                logger.error("Failed to import legacy tag translations: \(error)", category: Self.logCategory)
                failure = error
            }
        }
        if let failure { throw failure }
    }
}

// MARK: Helpers

extension TagTranslationService {
    struct Prepared: Sendable {
        var rows: [StoredTagTranslation]
        var table: [String: TagTranslationDisplay]
    }

    /// Converts (for Traditional Chinese, given the preferred languages) and prepares rows plus
    /// the in-memory table.
    @concurrent
    nonisolated static func prepare(
        _ translations: [String: TagTranslation], traditionalChineseFor preferredLanguages: [String]?
    ) async -> Prepared {
        let rows = await TagTranslationPreparation.prepare(translations, traditionalChineseFor: preferredLanguages)
        var table = [String: TagTranslationDisplay](minimumCapacity: rows.count)
        for row in rows {
            table[row.key] = TagTranslationDisplay(displayValue: row.displayValue, valueImageURL: row.valueImageURL)
        }
        return Prepared(rows: rows, table: table)
    }

    /// Legacy `FileClient.importTagTranslator`: the file must decode as a database with at least
    /// one translation in a known namespace.
    @concurrent
    nonisolated static func decodeDatabaseFile(_ data: Data) async throws -> [String: TagTranslation] {
        guard let response = try? JSONDecoder().decode(EhTagTranslationDatabaseResponse.self, from: data) else {
            throw TagTranslationError.parseFailed
        }
        let translations = response.tagTranslations
        guard !translations.isEmpty else { throw TagTranslationError.parseFailed }
        return translations
    }

    @concurrent
    nonisolated static func decodeLegacyTranslator(_ data: Data) async -> TagTranslator? {
        try? JSONDecoder().decode(TagTranslator.self, from: data)
    }

    func setMetadata(_ newValue: TagTranslationMetadata) {
        metadata = newValue
        newValue.save(to: defaults.defaults)
    }

    private func withDatabaseError(_ operation: () async throws -> Void) async throws {
        do {
            try await operation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            logger.error("Tag translation database error: \(error)", category: Self.logCategory)
            throw TagTranslationError.databaseFailed
        }
    }

    nonisolated static func loadingState(after error: any Error) -> TagTranslationLoadingState {
        switch error {
        case is CancellationError: .idle
        case let error as TagTranslationError: .failed(error)
        case is DecodingError: .failed(.parseFailed)
        default: .failed(.networkingFailed)
        }
    }

    /// Runs `operation` after every earlier one has finished, so changes to the stored
    /// translations never interleave. It runs in the caller's task and sees its cancellation.
    func serialized(_ operation: () async -> Void) async {
        let previous = mutationTail
        let (gate, open) = AsyncStream<Void>.makeStream()
        let current = Task { for await _ in gate {} }
        mutationTail = current
        await previous?.value
        await operation()
        open.finish()
        if mutationTail == current { mutationTail = nil }
    }
}
