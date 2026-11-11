import ConcurrencyExtras
import Dependencies
@testable import EhCore
@testable import EhFeatures
import EhModels
import Foundation
import Testing

@MainActor @Suite struct AppLockModelTests {
    private let clock = ShellTestClock()
    private let settings = SettingsStore(storage: .ephemeral())

    /// A lock whose passcode check has run, as the launch runs it before the lock is used.
    private func makeLock(biometrics: BiometricsClient = AppFixture.biometrics()) async -> AppLockModel {
        let lock = withDependencies {
            $0.settings = settings
            $0.date = clock.generator
            $0.biometricsClient = biometrics
        } operation: {
            AppLockModel()
        }
        await lock.checkPasscode()
        return lock
    }

    // MARK: Thresholds

    @Test(arguments: AutoLockPolicy.allCases.filter { $0 != .never })
    func locksExactlyAtTheThreshold(policy: AutoLockPolicy) async {
        settings.autoLockPolicy = policy
        let lock = await makeLock()
        let threshold = TimeInterval(policy.rawValue)

        if threshold > 0 {
            lock.sceneBecameInactive()
            clock.advance(by: threshold - 1)
            #expect(lock.sceneBecameActive() == .unlocked)
            #expect(!lock.isLocked)
            #expect(lock.blurRadius == 0)
        }

        lock.sceneBecameInactive()
        clock.advance(by: threshold)
        #expect(lock.sceneBecameActive() == .locked)
        #expect(lock.isLocked)
        #expect(lock.blurRadius == settings.backgroundBlurRadius)
    }

    @Test func neverLocksWithAutoLockOff() async {
        let lock = await makeLock()
        lock.sceneBecameInactive()
        clock.advance(by: 24 * 60 * 60)

        #expect(lock.sceneBecameActive() == .unlocked)
        #expect(!lock.isLocked)
    }

    @Test func instantlyLocksOnAnyReturn() async {
        settings.autoLockPolicy = .instantly
        let lock = await makeLock()

        lock.sceneBecameInactive()

        #expect(lock.sceneBecameActive() == .locked)
    }

    @Test func returningThroughInactiveKeepsTheFirstResignationTime() async {
        settings.autoLockPolicy = .min1
        let lock = await makeLock()

        lock.sceneBecameInactive()
        clock.advance(by: 30)
        lock.sceneEnteredBackground()
        clock.advance(by: 30)
        // On the way back the scene passes through inactive again.
        lock.sceneBecameInactive()

        #expect(lock.sceneBecameActive() == .locked)
    }

    // MARK: Blur

    @Test func blursWhileInactiveAndClearsOnReturn() async {
        settings.backgroundBlurRadius = 25
        let lock = await makeLock()

        lock.sceneBecameInactive()
        #expect(lock.blurRadius == 25)
        #expect(!lock.isLocked)

        #expect(lock.sceneBecameActive() == .unlocked)
        #expect(lock.blurRadius == 0)
    }

    @Test func zeroRadiusMeansNoBlur() async {
        settings.backgroundBlurRadius = 0
        let lock = await makeLock()

        lock.sceneBecameInactive()

        #expect(lock.blurRadius == 0)
    }

    // MARK: Authentication

    @Test func successfulAuthenticationUnlocks() async {
        settings.autoLockPolicy = .instantly
        let reason = LockIsolated("")
        let lock = await makeLock(biometrics: BiometricsClient(isAvailable: { true }, authenticate: { text in
            reason.setValue(text)
            return true
        }))
        lock.localizedReason = "Locked"
        lock.sceneBecameInactive()
        _ = lock.sceneBecameActive()

        let unlocked = await lock.authenticate()

        #expect(unlocked)
        #expect(!lock.isLocked)
        #expect(lock.blurRadius == 0)
        #expect(reason.value == "Locked")
    }

    @Test func failedAuthenticationStaysLockedWithoutPromptingAgain() async {
        settings.autoLockPolicy = .instantly
        let gate = ShellGate()
        let lock = await makeLock(biometrics: BiometricsClient(isAvailable: { true }, authenticate: { _ in
            await gate.wait()
            return false
        }))
        lock.sceneBecameInactive()
        _ = lock.sceneBecameActive()

        let attempt = Task { await lock.authenticate() }
        await shellWaitUntil { gate.isWaiting }
        // The system prompt makes the scene inactive, then active again.
        lock.sceneBecameInactive()
        gate.open()
        let unlocked = await attempt.value
        #expect(!unlocked)
        #expect(lock.sceneBecameActive() == .ignored)
        #expect(lock.isLocked)

        // A real trip to the background asks again.
        lock.sceneEnteredBackground()
        #expect(lock.sceneBecameActive() == .locked)
    }

    @Test func promptActivationBeforeTheResultIsIgnored() async {
        settings.autoLockPolicy = .instantly
        let gate = ShellGate()
        let lock = await makeLock(biometrics: BiometricsClient(isAvailable: { true }, authenticate: { _ in
            await gate.wait()
            return true
        }))
        lock.sceneBecameInactive()
        _ = lock.sceneBecameActive()

        let attempt = Task { await lock.authenticate() }
        await shellWaitUntil { gate.isWaiting }
        lock.sceneBecameInactive()
        #expect(lock.sceneBecameActive() == .ignored)
        gate.open()

        #expect(await attempt.value)
        #expect(!lock.isLocked)
        #expect(lock.sceneBecameActive() == .unlocked)
    }

    @Test func authenticateDoesNothingWhenUnlocked() async {
        let lock = await makeLock(biometrics: BiometricsClient(isAvailable: { true }, authenticate: { _ in
            Issue.record("Not locked")
            return true
        }))

        #expect(await lock.authenticate() == false)
    }

    @Test func withoutAPasscodeTheAppIsNeverLocked() async {
        settings.autoLockPolicy = .instantly
        let lock = await makeLock(biometrics: AppFixture.biometrics(available: false))

        lock.sceneBecameInactive()

        #expect(lock.sceneBecameActive() == .unlocked)
        #expect(!lock.isLocked)
    }

    // MARK: Launch

    @Test func lockAtLaunchFollowsThePolicy() async {
        #expect(await makeLock().lockAtLaunch() == false)

        settings.autoLockPolicy = .min30
        let lock = await makeLock()
        #expect(lock.lockAtLaunch())
        #expect(lock.isLocked)
        #expect(lock.blurRadius == settings.backgroundBlurRadius)
    }
}

@MainActor @Suite struct AppLockPasscodeTests {
    /// `LAContext` may block, so the passcode is checked off the main actor ahead of time and a
    /// returning scene only reads the result.
    @Test func thePasscodeIsCheckedOffTheMainActorAndNotOnActivation() async {
        let settings = SettingsStore(storage: .ephemeral())
        settings.autoLockPolicy = .instantly
        let checks = LockIsolated<[Bool]>([])
        let lock = withDependencies {
            $0.settings = settings
            $0.date = ShellTestClock().generator
            $0.biometricsClient = BiometricsClient(isAvailable: {
                checks.withValue { $0.append(Thread.isMainThread) }
                return true
            }, authenticate: { _ in true })
        } operation: {
            AppLockModel()
        }

        await lock.checkPasscode()
        #expect(checks.value == [false])

        lock.sceneBecameInactive()
        #expect(lock.sceneBecameActive() == .locked)
        #expect(checks.value == [false])
    }
}
