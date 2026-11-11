import EhDatabase
@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@MainActor @Suite struct AccountSessionTests {
    // MARK: isLoggedIn

    @Test func initialStateReadsTheCookies() async throws {
        let harness = try await AccountHarness()
        #expect(!harness.session.isLoggedIn)

        harness.setLogin(on: .ehentai)
        let session = harness.make { AccountSession() }
        #expect(session.isLoggedIn)
    }

    @Test func cookiesDidChangeRecomputesTheState() async throws {
        let harness = try await AccountHarness()
        let revision = harness.session.cookieRevision

        harness.setLogin(on: .exhentai)
        harness.session.cookiesDidChange()
        // ExHentai alone needs a usable igneous.
        #expect(!harness.session.isLoggedIn)

        harness.setLogin(on: .exhentai, igneous: CookieValueConstant.mystery)
        harness.session.cookiesDidChange()
        #expect(!harness.session.isLoggedIn)

        harness.setLogin(on: .exhentai, igneous: "ig")
        harness.session.cookiesDidChange()
        #expect(harness.session.isLoggedIn)
        #expect(harness.session.cookieRevision == revision + 3)
    }

    // MARK: refresh

    @Test func refreshDoesNothingWhenLoggedOut() async throws {
        let harness = try await AccountHarness()
        await harness.session.refresh()
        #expect(harness.transport.requests.isEmpty)
    }

    @Test func refreshPinsTheExistingProfileAndLoadsCategories() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        harness.transport.on(.settingsPage, reply: AccountFixture.settings)

        await harness.session.refresh()

        #expect(harness.cookie(CookieName.selectedProfile, GalleryHost.ehentai.url) == "2")
        #expect(harness.user.favoriteCategories?.count == 10)
        #expect(harness.requests("POST", path: "/uconfig.php").isEmpty)
        // E-Hentai has no ExHentai credentials, so no igneous fetch.
        #expect(!harness.transport.requests.contains { $0.url?.host == "exhentai.org" })
    }

    @Test func refreshCreatesTheProfileWhenMissing() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        harness.transport.on(.settingsPage, reply: try AccountFixture.settingsWithoutEhPandaProfile())
        harness.transport.on(.settingsPost, reply: AccountFixture.settings)

        await harness.session.refresh()

        let posts = harness.requests("POST", path: "/uconfig.php")
        #expect(posts.count == 1)
        let body = posts.first.map(AccountHarness.body(of:)) ?? ""
        #expect(body.contains("profile_action=create"))
        #expect(body.contains("profile_name=EhPanda"))
        #expect(harness.cookie(CookieName.selectedProfile, GalleryHost.ehentai.url) == "2")
    }

    @Test func refreshFetchesIgneousFirstWhenMissing() async throws {
        let harness = try await AccountHarness()
        harness.settings.galleryHost = .exhentai
        harness.setLogin(on: .ehentai)
        harness.setLogin(on: .exhentai)
        harness.transport.on(.igneous, reply: AccountFixture.setCookie("igneous=fresh; path=/; domain=.exhentai.org"))
        harness.transport.on(.settingsPage, reply: AccountFixture.settings)

        await harness.session.refresh()

        #expect(harness.transport.requests.first?.url?.host == "exhentai.org")
        #expect(harness.cookie(CookieName.igneous, GalleryHost.exhentai.url) == "fresh")
        #expect(harness.cookie(CookieName.igneous, URL(string: "https://s.exhentai.org/")!) == "fresh")
        #expect(harness.cookie(CookieName.selectedProfile, GalleryHost.exhentai.url) == "2")
        #expect(harness.session.isLoggedIn)
    }

    @Test func aFailedIgneousFetchDoesNotStopTheOtherSteps() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        harness.setLogin(on: .exhentai)
        harness.transport.on(.igneous, reply: .error(URLError(.timedOut)))
        harness.transport.on(.settingsPage, reply: AccountFixture.settings)

        await harness.session.refresh()

        #expect(harness.cookie(CookieName.igneous, GalleryHost.exhentai.url).isEmpty)
        #expect(harness.user.favoriteCategories?.count == 10)
        #expect(harness.cookie(CookieName.selectedProfile, GalleryHost.ehentai.url) == "2")
    }

    @Test func aFailedSettingsRequestDoesNotStopTheOther() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        // The categories and the profile check both read the settings page, concurrently;
        // whichever asks first fails.
        harness.transport.on(.settingsPage, replies: .error(URLError(.timedOut)), AccountFixture.settings)

        await harness.session.refresh()

        let loadedCategories = harness.user.favoriteCategories != nil
        let pinnedProfile = harness.cookie(CookieName.selectedProfile, GalleryHost.ehentai.url) == "2"
        #expect(harness.requests("GET", path: "/uconfig.php").count == 2)
        #expect(loadedCategories != pinnedProfile)
    }

    // MARK: logout

    @Test func logoutCleansEverythingUp() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        harness.setLogin(on: .exhentai, igneous: "ig")
        harness.session.cookiesDidChange()
        harness.user.apply(User(displayName: "me", favoriteCategories: [0: "Mine"]))
        try await harness.database.upsertPages([GalleryPage(gid: "1", index: 1, imageURL: URL(string: "https://a/1.jpg"))])
        #expect(harness.session.isLoggedIn)

        await harness.session.logout()

        #expect(!harness.session.isLoggedIn)
        #expect(harness.storage.cookies?.isEmpty == true)
        #expect(harness.user.user == User())
        #expect(try await harness.database.pages(gid: "1").isEmpty)
        #expect(harness.diskCacheClears.count == 1)
    }

    // MARK: login completion

    @Test func loginCompletionTidiesCookiesAndStartsUpkeep() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        harness.cookies.setOrEditCookie(for: GalleryHost.exhentai.url, name: CookieName.yay, value: "louder")
        harness.transport.on(.igneous, reply: AccountFixture.setCookie("igneous=fresh; path=/"))
        harness.transport.on(.settingsPage, reply: AccountFixture.settings)

        harness.session.loginDidComplete()
        #expect(harness.session.isLoggedIn)
        #expect(harness.cookie(CookieName.yay, GalleryHost.exhentai.url).isEmpty)
        // The E-Hentai login is copied to ExHentai, which then lacks only igneous.
        #expect(harness.cookie(CookieName.ipbMemberId, GalleryHost.exhentai.url) == "123")

        await harness.session.loginUpkeep?.value
        #expect(harness.cookie(CookieName.igneous, GalleryHost.exhentai.url) == "fresh")
        #expect(harness.user.favoriteCategories != nil)
    }

    @Test func selectProfileWritesTheCurrentHost() async throws {
        let harness = try await AccountHarness()
        harness.settings.galleryHost = .exhentai
        harness.session.selectProfile(7)
        #expect(harness.cookie(CookieName.selectedProfile, GalleryHost.exhentai.url) == "7")
        #expect(harness.cookie(CookieName.selectedProfile, GalleryHost.ehentai.url).isEmpty)
    }
}
