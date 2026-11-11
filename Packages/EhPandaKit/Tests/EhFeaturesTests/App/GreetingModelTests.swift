import Dependencies
@testable import EhCore
@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@MainActor @Suite struct GreetingModelTests {
    private let transport = StubTransport()
    private let settings = SettingsStore(storage: .ephemeral())
    private let userStore = UserStore(storage: .ephemeral())
    private let router = AppRouter()
    /// 2026-01-15 10:00 UTC. In the past, because the client stamps greetings with the real
    /// time and the store keeps only newer ones.
    private let clock = TestClock(Date(timeIntervalSince1970: 1_768_471_200))

    private static let noRewardPage = "<html><body><div id='eventpane'><p>It is the dawn of a new day!</p></div></body></html>"

    private func makeModel(loggedIn: Bool = true) -> GreetingModel {
        let cookies = loggedIn ? AppFixture.loggedInCookies() : AppFixture.loggedOutCookies()
        return withDependencies {
            $0.ehClient = AppFixture.client(transport, cookies: cookies)
            $0.cookieStore = cookies
            $0.settings = settings
            $0.userStore = userStore
            $0.date = clock.generator
        } operation: {
            GreetingModel(router: router)
        }
    }

    // MARK: Schedule

    @Test func isDueOncePerUTCDay() {
        let now = clock.date
        let startOfDay = Date(timeIntervalSince1970: 1_768_435_200)

        #expect(GreetingModel.isDue(lastUpdate: nil, now: now))
        #expect(GreetingModel.isDue(lastUpdate: Greeting(updateTime: nil), now: now))
        #expect(GreetingModel.isDue(lastUpdate: Greeting(updateTime: startOfDay - 1), now: now))
        #expect(!GreetingModel.isDue(lastUpdate: Greeting(updateTime: startOfDay), now: now))
        #expect(!GreetingModel.isDue(lastUpdate: Greeting(updateTime: now - 60), now: now))
        // Legacy also required "now" to be past the day's first instant.
        #expect(!GreetingModel.isDue(lastUpdate: Greeting(updateTime: startOfDay - 1), now: startOfDay))
    }

    // MARK: Fetching

    @Test func rewardIsStoredAndAnnounced() async throws {
        settings.showsNewDawnGreeting = true
        transport.on(.any, reply: .fixture(AppFixture.detailWithGreeting))
        let model = makeModel()

        await model.fetchIfNeeded()

        #expect(transport.requests.map { $0.url?.absoluteString } == ["https://e-hentai.org/news.php"])
        let greeting = try #require(userStore.greeting)
        #expect(greeting.gainedEXP == 30)
        #expect(router.presentedGreeting == greeting)
    }

    @Test func greetingWithoutRewardsIsStoredButNotAnnounced() async {
        settings.showsNewDawnGreeting = true
        transport.on(.any, reply: .html(Self.noRewardPage))
        let model = makeModel()

        await model.fetchIfNeeded()

        #expect(userStore.greeting?.gainedNothing == true)
        #expect(router.presentedGreeting == nil)
    }

    @Test func pageWithoutAGreetingSuppressesTheRestOfTheDay() async {
        settings.showsNewDawnGreeting = true
        transport.on(.any, reply: .fixture(AppFixture.detailPage))
        let model = makeModel()

        await model.fetchIfNeeded()
        #expect(userStore.greeting?.updateTime == clock.date)
        #expect(userStore.greeting?.gainedNothing == true)

        clock.advance(by: 60 * 60)
        await model.fetchIfNeeded()
        #expect(transport.requests.count == 1)
    }

    @Test func networkFailureStoresNothing() async {
        settings.showsNewDawnGreeting = true
        transport.on(.any, reply: .error(URLError(.timedOut)))
        let model = makeModel()

        await model.fetchIfNeeded()

        #expect(userStore.greeting == nil)
        #expect(router.presentedGreeting == nil)
    }

    @Test func notFetchedWhenLoggedOut() async {
        settings.showsNewDawnGreeting = true
        let model = makeModel(loggedIn: false)

        await model.fetchIfNeeded()

        #expect(transport.requests.isEmpty)
    }

    @Test func notFetchedWhenTheSettingIsOff() async {
        let model = makeModel()

        await model.fetchIfNeeded()

        #expect(transport.requests.isEmpty)
    }

    @Test func notFetchedAgainTheSameDay() async {
        settings.showsNewDawnGreeting = true
        userStore.updateGreeting(Greeting(gainedEXP: 1, updateTime: clock.date - 60))
        let model = makeModel()

        await model.fetchIfNeeded()

        #expect(transport.requests.isEmpty)
    }

    @Test func fetchedAgainTheNextDay() async {
        settings.showsNewDawnGreeting = true
        userStore.updateGreeting(Greeting(gainedEXP: 1, updateTime: clock.date - 24 * 60 * 60))
        transport.on(.any, reply: .fixture(AppFixture.detailWithGreeting))
        let model = makeModel()

        await model.fetchIfNeeded()

        #expect(transport.requests.count == 1)
        #expect(userStore.greeting?.gainedEXP == 30)
    }
}
