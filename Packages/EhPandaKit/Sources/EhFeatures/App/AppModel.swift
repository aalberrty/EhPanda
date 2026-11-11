import Dependencies
import EhCore
import EhModels
import Foundation
import Observation

/// The app around the features: the launch sequence, the scene lifecycle, the app lock, links
/// from outside the app and the daily greeting.
///
/// The shell owns one with `@State` and renders `launchState`. Feature screens are created only
/// once it is `.ready`, which is after the database has been installed for `\.database`.
@Observable
public final class AppModel {
    public enum LaunchState: Equatable, Sendable {
        /// Opening the database and importing the old app's data.
        case launching
        /// The tabs are shown; post-launch work may still be running.
        case ready
        /// The database could not be opened. The user may drop it and try again.
        case failed(AppError)
    }

    /// Work to run when the app is in front again, in `.task(id:)` so a newer request replaces
    /// an older one.
    public struct ActivationRequest: Equatable, Sendable {
        public enum Work: Equatable, Sendable {
            /// Ask for authentication, then run the unlock follow-ups.
            case authenticate
            /// The "on every unlock" follow-ups: greeting and clipboard.
            case followUps
        }

        let id: Int
        public let work: Work
    }

    public enum ScenePhase: Equatable, Sendable {
        case active, inactive, background
    }

    public internal(set) var launchState: LaunchState = .launching
    /// Bumped to (re)start the launch sequence; the shell runs `launch` in `.task(id:)` on it.
    public private(set) var launchAttempt = 0
    /// The "Drop the database" confirmation dialog is shown.
    public var isConfirmingDatabaseDrop = false
    public private(set) var activationRequest: ActivationRequest?
    /// Bumped when re-selecting a tab should give soft haptic feedback.
    public private(set) var tabReselectionFeedback = 0

    public let router: AppRouter
    public let lock: AppLockModel
    public let links: DeepLinkModel
    let greeting: GreetingModel

    @ObservationIgnored var scenePhase: ScenePhase?
    @ObservationIgnored var dropsDatabaseBeforeLaunch = false
    @ObservationIgnored private var activationCount = 0

    @ObservationIgnored @Dependency(\.launchClient) var launchClient
    @ObservationIgnored @Dependency(\.settings) var settings
    @ObservationIgnored @Dependency(\.applicationClient) var application
    @ObservationIgnored @Dependency(\.domainFronting) var domainFronting
    @ObservationIgnored @Dependency(\.accountSession) var account
    @ObservationIgnored @Dependency(\.cookieStore) var cookies
    @ObservationIgnored @Dependency(\.continuousClock) var clock
    @ObservationIgnored @Dependency(\.appLogger) var logger

    /// Cheap: starts nothing. Call `launch` from the root view's `.task`.
    public init(router: AppRouter = AppRouter()) {
        self.router = router
        lock = AppLockModel()
        links = DeepLinkModel(router: router)
        greeting = GreetingModel(router: router)
    }

    // MARK: Database failure

    /// Drops the database and runs the launch sequence again (legacy "Drop the database").
    public func dropDatabase() {
        isConfirmingDatabaseDrop = false
        dropsDatabaseBeforeLaunch = true
        launchState = .launching
        launchAttempt += 1
    }

    // MARK: Scene phase

    /// Feeds the scene phase to the lock. Ignored until the launch has decided the initial lock,
    /// as legacy ignored it until the settings had loaded.
    public func scenePhaseChanged(to phase: ScenePhase) {
        scenePhase = phase
        guard launchState == .ready else { return }
        switch phase {
        case .inactive:
            lock.sceneBecameInactive()
        case .background:
            lock.sceneEnteredBackground()
        case .active:
            switch lock.sceneBecameActive() {
            case .locked: requestActivation(.authenticate)
            case .unlocked: requestActivation(.followUps)
            case .ignored: break
            }
        }
    }

    /// The lock control was tapped.
    public func unlock() {
        guard lock.isLocked, !lock.isAuthenticating else { return }
        requestActivation(.authenticate)
    }

    /// Runs the current activation request. Call from `.task(id: activationRequest)`.
    public func performActivationWork() async {
        guard let request = activationRequest else { return }
        switch request.work {
        case .authenticate:
            guard await lock.authenticate(), !Task.isCancelled else { return }
            await runUnlockFollowUps()
        case .followUps:
            await runUnlockFollowUps()
        }
    }

    func requestActivation(_ work: ActivationRequest.Work) {
        activationCount += 1
        activationRequest = ActivationRequest(id: activationCount, work: work)
    }

    /// Legacy `AppReducer` `.appLock(.unlockApp)`: the greeting, then the clipboard.
    private func runUnlockFollowUps() async {
        links.checkClipboard()
        await greeting.fetchIfNeeded()
    }

    // MARK: Tabs

    /// Selects a tab through the router and gives the legacy soft haptic on re-selection: always
    /// for Home and Search; for Favorites when it pops or (logged in) reloads; for Settings when
    /// it pops.
    public func selectTab(_ tab: AppTab) {
        let isReselection = tab == router.selectedTab
        let wasAtRoot = router.stack(for: tab).isAtRoot
        router.select(tab)
        guard isReselection else { return }
        let givesFeedback = switch tab {
        case .home, .search: true
        case .favorites: !wasAtRoot || cookies.didLogin
        case .settings: !wasAtRoot
        }
        if givesFeedback {
            tabReselectionFeedback += 1
        }
    }

    static let logCategory = "Launch"
}
