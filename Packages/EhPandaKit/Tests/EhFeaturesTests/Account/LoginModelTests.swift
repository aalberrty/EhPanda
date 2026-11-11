@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@MainActor @Suite struct LoginModelTests {
    @Test func loginIsDisabledUntilBothFieldsAreFilled() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { LoginModel() }
        #expect(model.isLoginDisabled)
        model.username = "user"
        #expect(model.isLoginDisabled)
        model.password = "pass"
        #expect(!model.isLoginDisabled)

        model.password = ""
        await model.login()
        #expect(harness.transport.requests.isEmpty)
        #expect(model.attemptCount == 0)
    }

    @Test func returnOnUsernameMovesToPassword() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { LoginModel() }
        model.focusedField = .username
        await model.submit()
        #expect(model.focusedField == .password)
        #expect(harness.transport.requests.isEmpty)
    }

    @Test func successfulLoginSignsInAndStartsUpkeep() async throws {
        let harness = try await AccountHarness()
        harness.transport.on(.login, reply: AccountFixture.loginCookies)
        harness.transport.on(.igneous, reply: .status(200))
        harness.transport.on(.settingsPage, reply: AccountFixture.settings)
        let model = harness.make { LoginModel() }
        model.username = "user"
        model.password = "p&ss=w+rd"
        model.focusedField = .password

        await model.submit()

        #expect(model.didLogin)
        #expect(model.loginState == .idle)
        #expect(model.focusedField == nil)
        #expect(model.attemptCount == 1)
        #expect(harness.session.isLoggedIn)
        #expect(harness.cookie(CookieName.ipbMemberId, GalleryHost.exhentai.url) == "42")
        let body = harness.transport.requests.first.map(AccountHarness.body(of:)) ?? ""
        #expect(body.contains("UserName=user"))

        await harness.session.loginUpkeep?.value
        #expect(harness.cookie(CookieName.selectedProfile, GalleryHost.ehentai.url) == "2")
    }

    @Test func rejectedLoginFails() async throws {
        let harness = try await AccountHarness()
        harness.transport.on(.login, reply: .html("<html>Wrong password</html>"))
        let model = harness.make { LoginModel() }
        model.username = "user"
        model.password = "wrong"

        await model.login()

        #expect(!model.didLogin)
        #expect(model.loginState == .failed(.unknown))
        #expect(!harness.session.isLoggedIn)
        #expect(harness.session.loginUpkeep == nil)
    }

    @Test func networkFailureIsReported() async throws {
        let harness = try await AccountHarness()
        harness.transport.on(.login, reply: .error(URLError(.notConnectedToInternet)))
        let model = harness.make { LoginModel() }
        model.username = "user"
        model.password = "pass"

        await model.login()

        #expect(model.loginState == .failed(.networkingFailed))
    }

    // MARK: Web login

    @Test func webLoginIsUnavailableWithDomainFronting() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { LoginModel() }
        model.presentWebLogin()
        #expect(model.webLoginURL == EhEndpoints.webLogin)

        model.webLoginURL = nil
        harness.settings.bypassesSNIFiltering = true
        #expect(!model.isWebLoginAvailable)
        model.presentWebLogin()
        #expect(model.webLoginURL == nil)
    }

    @Test func webLoginAdoptsTheForumCookies() async throws {
        let harness = try await AccountHarness()
        harness.transport.on(.igneous, reply: .status(200))
        harness.transport.on(.settingsPage, reply: AccountFixture.settings)
        let model = harness.make { LoginModel() }
        model.presentWebLogin()

        model.webLoginDidFinish(cookies: [
            WebCookie(name: CookieName.ipbMemberId, value: "7", domain: ".e-hentai.org"),
            WebCookie(name: CookieName.ipbPassHash, value: "hash", domain: ".e-hentai.org"),
            WebCookie(name: "session_id", value: "x", domain: ".e-hentai.org"),
            WebCookie(name: CookieName.ipbMemberId, value: "9", domain: "example.com")
        ])

        #expect(model.webLoginURL == nil)
        #expect(model.didLogin)
        #expect(harness.session.isLoggedIn)
        #expect(harness.cookie(CookieName.ipbMemberId, GalleryHost.ehentai.url) == "7")
        #expect(harness.cookie(CookieName.ipbMemberId, GalleryHost.exhentai.url) == "7")
        #expect(harness.cookie("session_id", GalleryHost.ehentai.url).isEmpty)
        await harness.session.loginUpkeep?.value
    }

    @Test func webLoginWithoutCredentialsFails() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { LoginModel() }
        model.webLoginDidFinish(cookies: [WebCookie(name: CookieName.ipbMemberId, value: "7", domain: ".e-hentai.org")])
        #expect(!model.didLogin)
        #expect(model.loginState == .failed(.unknown))
    }
}
