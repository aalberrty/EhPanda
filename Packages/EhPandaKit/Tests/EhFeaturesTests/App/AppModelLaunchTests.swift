import ConcurrencyExtras
import Dependencies
@testable import EhCore
import EhDatabase
@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

/// An `AppModel` whose launch steps are stubs that log what they see.
@MainActor
final class LaunchHarness {
    enum StubError: Error { case cannotOpen, cannotDrop }

    let events = EventLog()
    let settings = SettingsStore(storage: .ephemeral())
    let clock = TestClock()
    let transport = StubTransport()
    var model: AppModel!

    /// - Parameters:
    ///   - openFailures: how many database opens fail before one succeeds.
    ///   - expireGate: holds the post-launch page expiry until opened.
    init(
        openFailures: Int = 0, dropFails: Bool = false, isPad: Bool = false,
        alternateIconName: String? = nil, biometrics: BiometricsClient = AppFixture.biometrics(),
        clipboard: ClipboardClient = AppFixture.clipboard(), expireGate: Gate? = nil
    ) {
        let events = events
        let opens = LockIsolated(0)
        let modelBox = LockIsolated<AppModel?>(nil)
        let launchClient = LaunchClient(
            prepareCookies: { events.record("cookies") },
            openDatabase: {
                events.record("open")
                let attempt = opens.withValue { $0 += 1; return $0 }
                if attempt <= openFailures { throw StubError.cannotOpen }
                return try await AppDatabase.inMemory()
            },
            dropDatabase: {
                events.record("drop")
                if dropFails { throw StubError.cannotDrop }
            },
            installDatabase: { _ in events.record("install") },
            importLegacyData: { _ in
                events.record("import while \(modelBox.value.map { "\($0.launchState)" } ?? "?")")
                return .nothingToImport
            },
            expirePages: { _ in
                events.record("expire")
                await expireGate?.wait()
                events.record("expired")
            }
        )
        let model = withDependencies {
            $0.launchClient = launchClient
            $0.settings = settings
            $0.date = clock.generator
            $0.continuousClock = InstantClock()
            $0.applicationClient = AppFixture.application(isPad: isPad, alternateIconName: alternateIconName, events: events)
            $0.domainFronting = AppFixture.domainFronting(events: events)
            $0.biometricsClient = biometrics
            $0.clipboardClient = clipboard
            $0.ehClient = AppFixture.client(transport)
        } operation: {
            AppModel()
        }
        self.model = model
        modelBox.withValue { $0 = model }
    }

    func launch(isRegularWidth: Bool = false) async {
        await model.launch(isRegularWidth: isRegularWidth)
    }
}

@MainActor @Suite struct AppModelLaunchTests {
    @Test func installsTheDatabaseBeforeTheTabsCanReadIt() async throws {
        let harness = LaunchHarness()
        #expect(harness.model.launchState == .launching)

        await harness.launch()

        let events = harness.events
        let install = try #require(events.index(of: "install"))
        #expect(try #require(events.index(of: "open")) < install)
        #expect(try #require(events.index(of: "cookies")) < install)
        // The import runs on the installed database, before the tabs exist.
        #expect(try #require(events.index(of: "import while launching")) > install)
        #expect(try #require(events.index(of: "expire")) > install)
        #expect(harness.model.launchState == .ready)
    }

    @Test func linksWaitUntilTheDatabaseIsInstalled() async {
        let harness = LaunchHarness()
        harness.transport.on(.path("/g/3103480/0000000000/"), reply: .fixture(AppFixture.detailPage))
        harness.model.links.open(AppFixture.galleryURL)

        await harness.model.links.handleRequest()
        #expect(harness.transport.requests.isEmpty)
        #expect(harness.model.links.request != nil)

        await harness.launch()
        await harness.model.links.handleRequest()
        #expect(harness.transport.requests.count == 1)
        #expect(harness.model.router.presentedGallery?.gid == "3103480")
    }

    @Test(arguments: [(true, ListDisplayMode.thumbnail), (false, .detail)])
    func registersTheListDisplayModeForTheWidth(isRegularWidth: Bool, expected: ListDisplayMode) async {
        let harness = LaunchHarness()

        await harness.launch(isRegularWidth: isRegularWidth)

        #expect(harness.settings.listDisplayMode == expected)
    }

    @Test func appliesDomainFrontingBeforeAnyRequest() async throws {
        let harness = LaunchHarness()
        harness.settings.bypassesSNIFiltering = true

        await harness.launch()

        let applied = try #require(harness.events.index(of: "domainFronting true"))
        #expect(applied < (try #require(harness.events.index(of: "install"))))
    }

    @Test(arguments: [(false, OrientationLock.portrait), (true, .unlocked)])
    func appliesTheDefaultOrientation(isPad: Bool, expected: OrientationLock) async {
        let harness = LaunchHarness(isPad: isPad)

        await harness.launch()

        #expect(harness.events.all.contains("orientation \(expected)"))
    }

    @Test func databaseFailureStopsBeforeTheTabs() async {
        let harness = LaunchHarness(openFailures: 1)

        await harness.launch()

        guard case .failed(.databaseCorrupted(let reason)) = harness.model.launchState else {
            Issue.record("Expected a database failure, got \(harness.model.launchState)")
            return
        }
        #expect(reason?.contains("cannotOpen") == true)
        #expect(harness.events.index(of: "install") == nil)
        #expect(!harness.events.all.contains { $0.hasPrefix("import") })
        #expect(harness.events.index(of: "expire") == nil)
    }

    @Test func dropAndRetry() async {
        let harness = LaunchHarness(openFailures: 1)
        await harness.launch()
        let attempt = harness.model.launchAttempt
        harness.model.isConfirmingDatabaseDrop = true

        harness.model.dropDatabase()

        #expect(!harness.model.isConfirmingDatabaseDrop)
        #expect(harness.model.launchState == .launching)
        #expect(harness.model.launchAttempt == attempt + 1)

        await harness.launch()

        #expect(harness.events.all.filter { ["open", "drop", "install"].contains($0) } == ["open", "drop", "open", "install"])
        #expect(harness.model.launchState == .ready)
    }

    @Test func failedDropShowsTheErrorAgain() async {
        let harness = LaunchHarness(openFailures: 1, dropFails: true)
        await harness.launch()

        harness.model.dropDatabase()
        await harness.launch()

        #expect(harness.events.all.filter { $0 == "open" }.count == 1)
        guard case .failed(.databaseCorrupted) = harness.model.launchState else {
            Issue.record("Expected a database failure, got \(harness.model.launchState)")
            return
        }
    }

    @Test func postLaunchWorkDoesNotHoldBackTheTabs() async {
        let gate = Gate()
        let harness = LaunchHarness(expireGate: gate)

        let launch = Task { await harness.launch() }
        await waitUntil { gate.isWaiting }

        #expect(harness.model.launchState == .ready)
        #expect(!harness.events.all.contains("expired"))

        gate.open()
        await launch.value
        #expect(harness.events.all.contains("expired"))
    }

    @Test func syncsTheAppIconFromTheSystem() async {
        let harness = LaunchHarness(alternateIconName: "AppIcon_Ukiyoe")

        await harness.launch()

        #expect(harness.settings.appIconType == .ukiyoe)
    }

    @Test func keepsTheStoredIconWhenThePrimaryIconIsShown() async {
        let harness = LaunchHarness(alternateIconName: nil)
        harness.settings.appIconType = .developer

        await harness.launch()

        #expect(harness.settings.appIconType == .developer)
    }

    @Test func locksAtLaunchWhenAutoLockIsOn() async {
        let harness = LaunchHarness()
        harness.settings.autoLockPolicy = .min5
        harness.model.scenePhaseChanged(to: .active)

        await harness.launch()

        #expect(harness.model.lock.isLocked)
        #expect(harness.model.lock.blurRadius == harness.settings.backgroundBlurRadius)
        #expect(harness.model.activationRequest?.work == .authenticate)
    }

    @Test func doesNotLockWithoutAPasscode() async {
        let harness = LaunchHarness(biometrics: AppFixture.biometrics(available: false))
        harness.settings.autoLockPolicy = .min5
        harness.model.scenePhaseChanged(to: .active)

        await harness.launch()

        #expect(!harness.model.lock.isLocked)
        #expect(harness.model.activationRequest?.work == .followUps)
    }

    @Test func unlockedLaunchRunsTheFollowUps() async {
        let harness = LaunchHarness()
        harness.model.scenePhaseChanged(to: .active)

        await harness.launch()

        #expect(!harness.model.lock.isLocked)
        #expect(harness.model.activationRequest?.work == .followUps)
    }

    @Test func waitsForTheSceneToBecomeActiveBeforeAuthenticating() async {
        let harness = LaunchHarness()
        harness.settings.autoLockPolicy = .instantly
        harness.model.scenePhaseChanged(to: .inactive)

        await harness.launch()

        #expect(harness.model.lock.isLocked)
        #expect(harness.model.activationRequest == nil)

        harness.model.scenePhaseChanged(to: .active)
        #expect(harness.model.activationRequest?.work == .authenticate)
    }

    @Test func scenePhaseIsIgnoredUntilReady() {
        let harness = LaunchHarness()

        harness.model.scenePhaseChanged(to: .inactive)

        #expect(harness.model.lock.blurRadius == 0)
    }

    @Test func followsTheDomainFrontingSetting() async {
        let harness = LaunchHarness()
        let following = Task { await harness.model.followDomainFrontingSetting() }
        defer { following.cancel() }

        harness.settings.bypassesSNIFiltering = true
        await waitUntil { harness.events.all.contains("domainFronting true") }
        harness.settings.bypassesSNIFiltering = false
        await waitUntil { harness.events.all.contains("domainFronting false") }
    }
}
