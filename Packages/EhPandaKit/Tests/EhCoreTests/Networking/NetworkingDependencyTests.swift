import Dependencies
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing
@testable import EhCore

struct NetworkingDependencyTests {
    @Test func testClientReportsAnIssueAndNeverReachesTheNetwork() async {
        @Dependency(\.ehClient) var client

        await withKnownIssue {
            await #expect(throws: AppError.networkingFailed) { try await client.greeting() }
        }
    }

    @Test func installedStubClientAnswersFromFixtures() async throws {
        let transport = StubTransport()
        transport.on(.any, reply: .fixture("Parser/Other/EhSetting.html"))
        let cookies = CookieStore(storage: InMemoryCookieStorage())

        let categories = try await withDependencies {
            $0.ehClient = EhClient(transport: transport, cookies: cookies, host: { .exhentai })
        } operation: {
            @Dependency(\.ehClient) var client
            return try await client.favoriteCategories()
        }

        #expect(categories.count == 10)
        #expect(transport.requests.first?.url?.host() == "exhentai.org")
    }

    @Test func testCookieStoreIsIsolatedFromTheSharedJar() {
        @Dependency(\.cookieStore) var cookies
        let url = GalleryHost.ehentai.url
        let name = "ehpanda_test_isolation"

        cookies.setOrEditCookie(for: url, name: name, value: "1")

        #expect(cookies.cookie(named: name, for: url).rawValue.isEmpty)
        #expect(HTTPCookieStorage.shared.cookies(for: url)?.contains { $0.name == name } != true)
    }

    @Test func liveCookieStoreUsesTheSharedJar() {
        // The live client and cookie store must see the same jar as the live transport.
        let name = "ehpanda_test_shared_\(UUID().uuidString)"
        let url = GalleryHost.ehentai.url
        CookieStore.liveValue.setOrEditCookie(for: url, name: name, value: "1")
        defer { HTTPCookieStorage.shared.cookies(for: url)?.filter { $0.name == name }.forEach(HTTPCookieStorage.shared.deleteCookie) }

        #expect(HTTPCookieStorage.shared.cookies(for: url)?.contains { $0.name == name } == true)
    }

    @Test func domainFrontingSwitchFlipsTheTransportFlag() {
        let transport = URLSessionTransport(cookieStorage: InMemoryCookieStorage())
        let domainFronting = DomainFrontingClient.transport(transport)
        #expect(!domainFronting.isEnabled())

        domainFronting.setEnabled(true)
        #expect(transport.isDomainFrontingEnabled)
        #expect(domainFronting.isEnabled())

        domainFronting.setEnabled(false)
        #expect(!transport.isDomainFrontingEnabled)
    }

    @Test func liveDomainFrontingActsOnTheLiveTransport() {
        let original = LiveNetwork.transport.isDomainFrontingEnabled
        defer { LiveNetwork.transport.isDomainFrontingEnabled = original }

        DomainFrontingClient.liveValue.setEnabled(!original)

        #expect(LiveNetwork.transport.isDomainFrontingEnabled == !original)
    }

    @Test func testDomainFrontingReportsIssues() {
        @Dependency(\.domainFronting) var domainFronting
        withKnownIssue { domainFronting.setEnabled(true) }
        withKnownIssue { _ = domainFronting.isEnabled() }
    }

    @Test func liveHostFollowsTheGalleryHostDefault() {
        let defaults = UserDefaults.standard
        let key = "galleryHost"
        let original = defaults.object(forKey: key)
        defer { defaults.set(original, forKey: key) }

        defaults.removeObject(forKey: key)
        #expect(LiveNetwork.hostProvider.current == .ehentai)
        defaults.set(GalleryHost.exhentai.rawValue, forKey: key)
        #expect(LiveNetwork.hostProvider.current == .exhentai)
    }
}
