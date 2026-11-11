import Dependencies
import EhCore
import EhModels
import Foundation
import Observation

/// The privacy blur and the auto-lock (legacy `AppLockReducer`).
///
/// The app blurs whenever its scene is not active. When it becomes active again after at least
/// the auto-lock threshold, it stays blurred, shows the lock and asks for device-owner
/// authentication. `AppModel` feeds it scene-phase changes and runs the authentication.
@Observable
public final class AppLockModel {
    /// The blur over the whole app; 0 when nothing is hidden.
    public private(set) var blurRadius: Double = 0
    /// The lock control is shown and the app stays blurred until authentication succeeds.
    public private(set) var isLocked = false

    /// The reason shown in the authentication prompt. Localized text lives in the app, which
    /// sets this once.
    @ObservationIgnored public var localizedReason = ""

    /// When the scene stopped being active. Kept from the first resignation until the next
    /// unlock, so returning through `inactive` from the background does not restart the timer.
    @ObservationIgnored private(set) var inactiveSince: Date?
    @ObservationIgnored private(set) var isAuthenticating = false
    /// The authentication prompt itself makes the scene inactive and then active again; that
    /// activation must not lock the app again (which would prompt again after a cancel).
    @ObservationIgnored private var ignoresNextActivation = false
    /// Whether the device can authenticate its owner, as last checked by `checkPasscode()`.
    /// `LAContext` may block, so it is checked off the main actor ahead of time (at launch and
    /// whenever the app goes to the background, which is the only way a passcode can be
    /// removed) rather than when the scene becomes active.
    @ObservationIgnored private(set) var isPasscodeSet = false

    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.date) private var date
    @ObservationIgnored @Dependency(\.biometricsClient) private var biometrics

    public enum Activation: Equatable, Sendable {
        /// Nothing is hidden any more: run the "on every unlock" follow-ups.
        case unlocked
        /// The auto-lock expired: authenticate.
        case locked
        /// Caused by the authentication prompt; nothing to do.
        case ignored
    }

    nonisolated public init() {}

    /// Checks off the main actor whether the device can authenticate its owner.
    func checkPasscode() async {
        isPasscodeSet = await Self.canAuthenticate(biometrics)
    }

    /// Locks right away if auto-lock is on, as legacy did after loading the settings (it treated
    /// the app as inactive since the distant past). Returns whether it locked. Call after
    /// `checkPasscode()`.
    @discardableResult
    func lockAtLaunch() -> Bool {
        inactiveSince = .distantPast
        guard shouldLock(now: date.now) else {
            inactiveSince = nil
            return false
        }
        lock()
        return true
    }

    func sceneBecameInactive() {
        guard !isAuthenticating else { return }
        blurRadius = settings.backgroundBlurRadius
        if inactiveSince == nil {
            inactiveSince = date.now
        }
    }

    func sceneEnteredBackground() {
        // The authentication prompt never sends the app to the background, so whatever comes
        // next is a real return to the app.
        ignoresNextActivation = false
        sceneBecameInactive()
    }

    func sceneBecameActive() -> Activation {
        guard !isAuthenticating, !ignoresNextActivation else {
            ignoresNextActivation = false
            return .ignored
        }
        if shouldLock(now: date.now) {
            lock()
            return .locked
        }
        unlock()
        return .unlocked
    }

    /// Asks for device-owner authentication; unlocks on success. Returns whether it unlocked.
    func authenticate() async -> Bool {
        guard isLocked, !isAuthenticating else { return false }
        isAuthenticating = true
        ignoresNextActivation = true
        let succeeded = await biometrics.authenticate(localizedReason)
        isAuthenticating = false
        if succeeded {
            unlock()
        }
        return succeeded
    }

    private func shouldLock(now: Date) -> Bool {
        let policy = settings.autoLockPolicy
        guard policy != .never, let since = inactiveSince,
              now.timeIntervalSince(since) >= Double(policy.rawValue)
        else { return false }
        // Without a passcode the device cannot authenticate its owner, and legacy then kept the
        // app locked for good. Blurring without locking avoids locking the user out.
        return isPasscodeSet
    }

    @concurrent
    nonisolated private static func canAuthenticate(_ biometrics: BiometricsClient) async -> Bool {
        biometrics.isAvailable()
    }

    private func lock() {
        blurRadius = settings.backgroundBlurRadius
        isLocked = true
    }

    private func unlock() {
        blurRadius = 0
        isLocked = false
        inactiveSince = nil
        ignoresNextActivation = false
    }
}
