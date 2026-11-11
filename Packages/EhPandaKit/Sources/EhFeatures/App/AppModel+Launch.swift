import Dependencies
import EhCore
import EhDatabase
import EhModels
import Foundation
import Observation

// The launch sequence (legacy `AppDelegateReducer.onLaunchFinish`, `MigrationReducer`,
// `SettingReducer.loadUserSettings`).
//
// Only what the first screen depends on blocks it: the database (opened alongside the cookie
// housekeeping), the one-time import and the settings that change how requests are sent.
// Everything else runs concurrently once the tabs are up, as child tasks of `launch`, so it is
// cancelled with the view's `.task`.

extension AppModel {
    /// Galleries not opened for this long lose their stored page URLs, which expire on the site.
    static let pageLifetime: TimeInterval = 7 * 24 * 60 * 60

    /// Legacy waited this long after "Drop the database" before dropping, showing the loading state.
    static let dropDelay: Duration = .milliseconds(500)

    /// Runs the launch sequence. Call from the root view's `.task(id: launchAttempt)`.
    ///
    /// - Parameter isRegularWidth: whether the window is regular width; lists default to the
    ///   thumbnail mode there (legacy: iPad-width screens).
    public func launch(isRegularWidth: Bool) async {
        guard launchState != .ready else { return }
        launchState = .launching
        guard await dropDatabaseIfRequested() else { return }

        settings.registerDefaultListDisplayMode(isRegularWidth ? .thumbnail : .detail)
        applyDomainFronting(settings.bypassesSNIFiltering)
        application.setOrientationLock(application.isPad() ? .unlocked : .portrait)

        let database: AppDatabase
        do {
            database = try await openDatabase()
        } catch is CancellationError {
            return
        } catch {
            logger.error("Opening the database failed: \(error)", category: Self.logCategory)
            launchState = .failed(.databaseCorrupted(String(describing: error)))
            return
        }
        launchClient.installDatabase(database)

        let report = await launchClient.importLegacyData(database)
        if report.outcome != .nothingToImport {
            logger.log(report.outcome == .completed ? .info : .error, report.description, category: Self.logCategory)
        }
        guard !Task.isCancelled else { return }

        lock.lockAtLaunch()
        launchState = .ready
        // Scene changes were ignored until now; catch up with the current phase, which also
        // starts the authentication or the unlock follow-ups when the scene is active.
        if let scenePhase {
            scenePhaseChanged(to: scenePhase)
        }
        await runPostLaunchWork(database: database)
    }

    /// Applies "Bypasses SNI filtering" whenever it changes. Call from a `.task` on the root
    /// view; it runs until cancelled. The launch applies the initial value itself.
    public func followDomainFrontingSetting() async {
        let changes = Observations { [settings] in settings.bypassesSNIFiltering }
        for await enabled in changes {
            applyDomainFronting(enabled)
        }
    }

    // MARK: Steps

    /// Returns `false` when the launch must stop (drop failed or cancelled).
    private func dropDatabaseIfRequested() async -> Bool {
        guard dropsDatabaseBeforeLaunch else { return true }
        dropsDatabaseBeforeLaunch = false
        do {
            try await clock.sleep(for: Self.dropDelay)
            try await launchClient.dropDatabase()
            return true
        } catch is CancellationError {
            return false
        } catch {
            logger.error("Dropping the database failed: \(error)", category: Self.logCategory)
            launchState = .failed(.databaseCorrupted(String(describing: error)))
            return false
        }
    }

    /// Opens the database while the cookie housekeeping runs, as legacy did both at once.
    private func openDatabase() async throws -> AppDatabase {
        async let cookiesPrepared: Void = launchClient.prepareCookies()
        let database = try await launchClient.openDatabase()
        await cookiesPrepared
        return database
    }

    private func runPostLaunchWork(database: AppDatabase) async {
        syncAppIcon()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.expirePages(in: database) }
            group.addTask { await self.account.refresh() }
            group.addTask { await self.prepareTagTranslations() }
        }
    }

    private func expirePages(in database: AppDatabase) async {
        do {
            try await database.deleteExpiredPages(notOpenedWithin: Self.pageLifetime)
        } catch {
            logger.warning("Deleting expired pages failed: \(error)", category: Self.logCategory)
        }
    }

    /// Loads the stored translations and, with the tags extension on, checks for an update.
    private func prepareTagTranslations() async {
        // TODO(tag-translation-service): `await tagTranslations.load()`, then
        // `fetchUpdates()` when `settings.enablesTagsExtension`, once the service is merged.
    }

    /// The stored choice can disagree with the icon the system actually shows (an imported
    /// setting, a switch that failed); the system wins. Legacy: `SettingReducer.syncAppIconType`.
    func syncAppIcon() {
        guard let name = application.alternateIconName() else { return }
        let icon = AppIconType.allCases.first { name.contains($0.filename) } ?? .default
        if settings.appIconType != icon {
            settings.appIconType = icon
        }
    }

    func applyDomainFronting(_ enabled: Bool) {
        guard domainFronting.isEnabled() != enabled else { return }
        domainFronting.setEnabled(enabled)
    }
}
