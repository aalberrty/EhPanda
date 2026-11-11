import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

struct AccountClientTests {
    private static let loginCookies = "ipb_member_id=4242; path=/; domain=.e-hentai.org, "
        + "ipb_pass_hash=cafe; path=/; domain=.e-hentai.org"

    @Test func loginStoresCredentialsOnBothHosts() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .html("<html>Thanks</html>", headers: ["Set-Cookie": Self.loginCookies]))

        try await harness.client.login(username: "user", password: "pass")

        let request = try harness.onlyRequest()
        #expect(line(request) == "POST https://forums.e-hentai.org/index.php?act=Login&CODE=01")
        #expect(request.httpBody == harness.builder.login(username: "user", password: "pass").httpBody)
        #expect(harness.cookies.didLogin)
        #expect(harness.cookies.memberID(for: .ehentai) == "4242")
        #expect(harness.cookies.memberID(for: .exhentai) == "4242")
        #expect(harness.cookies.passHash(for: .exhentai) == "cafe")
    }

    @Test func rejectedLoginThrowsAndStoresNothing() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html("<html>Username or password incorrect</html>"))

        let error = await thrownError { try await harness.client.login(username: "user", password: "wrong") }

        #expect(error as? AppError == .unknown)
        #expect(!harness.cookies.didLogin)
    }

    @Test func loginThatFailsToConnect() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .error(URLError(.notConnectedToInternet)))

        let error = await thrownError { try await harness.client.login(username: "user", password: "pass") }

        #expect(error as? AppError == .networkingFailed)
    }

    @Test func fetchIgneousStoresItForExhentaiOnly() async throws {
        let harness = ClientHarness()
        harness.logIn(host: .exhentai)
        harness.transport.on(.any, reply: .html("", headers: ["Set-Cookie": "igneous=abcdef; path=/; domain=.exhentai.org"]))

        try await harness.client.fetchIgneous()

        #expect(line(try harness.onlyRequest()) == "GET https://exhentai.org/")
        #expect(harness.cookies.igneous(for: .exhentai) == "abcdef")
        #expect(harness.cookies.igneous(for: .ehentai).isEmpty)
        #expect(!harness.cookies.shouldFetchIgneous)
    }

    @Test func verifyEhProfile() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .fixture(ClientFixture.ehSetting))

        let response = try await harness.client.verifyEhProfile()

        #expect(line(try harness.onlyRequest()) == "GET https://exhentai.org/uconfig.php")
        #expect(response == VerifyEhProfileResponse(profileValue: 2, isProfileNotFound: false))
    }

    @Test func ehSetting() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ehSetting))

        let setting = try await harness.client.ehSetting()

        #expect(line(try harness.onlyRequest()) == "GET https://e-hentai.org/uconfig.php")
        #expect(setting.ehProfiles.count == 3)
        #expect(setting.favoritesSortOrder == .favoritedTime)
    }

    @Test func ehProfilePostsTheActionAndParsesTheResultingSettings() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ehSetting))

        let setting = try await harness.client.ehProfile(action: .create, name: "EhPanda")

        let request = try harness.onlyRequest()
        #expect(line(request) == "POST https://e-hentai.org/uconfig.php")
        #expect(request.httpBody == harness.builder.ehProfile(action: .create, name: "EhPanda").httpBody)
        #expect(setting.ehProfiles.count == 3)
    }

    @Test func submitEhSetting() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ehSetting))
        let current = try await harness.client.ehSetting()
        harness.transport.reset()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ehSetting))

        _ = try await harness.client.submitEhSetting(current)

        let request = try harness.onlyRequest()
        #expect(line(request) == "POST https://e-hentai.org/uconfig.php")
        #expect(request.httpBody == harness.builder.submitEhSettingChanges(current).httpBody)
    }

    @Test func favoriteCategories() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ehSetting))

        let categories = try await harness.client.favoriteCategories()

        #expect(line(try harness.onlyRequest()) == "GET https://e-hentai.org/uconfig.php")
        #expect(categories == Dictionary(uniqueKeysWithValues: (0...9).map { ($0, "Favorites \($0)") }))
    }

    @Test func greetingIsAlwaysReadFromEhentaiNews() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .fixture(ClientFixture.detailWithGreeting))

        let greeting = try await harness.client.greeting()

        #expect(line(try harness.onlyRequest()) == "GET https://e-hentai.org/news.php")
        #expect(greeting.gainedEXP == 30)
        #expect(greeting.gainedCredits == 329)
    }

    @Test func pageWithoutGreeting() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.detail))

        let error = await thrownError { try await harness.client.greeting() }

        #expect(error as? AppError == .parseFailed)
    }
}
