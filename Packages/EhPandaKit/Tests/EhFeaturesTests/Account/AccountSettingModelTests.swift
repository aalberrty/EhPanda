@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@MainActor @Suite struct AccountSettingModelTests {
    private let sexhentai = URL(string: "https://s.exhentai.org/")!

    @Test func loadCookiesReportsEachState() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        harness.setExpiredCookie(CookieName.ipbPassHash, on: .exhentai)
        harness.cookies.setOrEditCookie(for: GalleryHost.exhentai.url, name: CookieName.igneous, value: CookieValueConstant.mystery)
        let model = harness.make { AccountSettingModel() }

        model.loadCookies()

        #expect(model.ehCookies.memberID.value == CookieValue(rawValue: "123", status: .valid))
        #expect(model.ehCookies.memberID.editingText == "123")
        #expect(model.exCookies.memberID.value.status == .notFound)
        #expect(model.exCookies.passHash.value.status == .expired)
        #expect(model.exCookies.igneous.value.status == .mystery)
    }

    @Test func committingWritesTrimmedValueToEveryHostURL() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { AccountSettingModel() }
        model.loadCookies()

        model.exCookies.igneous.editingText = "  abc "
        // Typing alone writes nothing.
        #expect(harness.cookie(CookieName.igneous, GalleryHost.exhentai.url).isEmpty)

        model.commit(.igneous, host: .exhentai)
        #expect(harness.cookie(CookieName.igneous, GalleryHost.exhentai.url) == "abc")
        #expect(harness.cookie(CookieName.igneous, sexhentai) == "abc")
        #expect(model.exCookies.igneous.value.status == .valid)
        #expect(model.exCookies.igneous.editingText == "abc")
    }

    @Test func committingKeepsOtherFieldsBeingEdited() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { AccountSettingModel() }
        model.loadCookies()
        model.ehCookies.memberID.editingText = "1"
        model.ehCookies.passHash.editingText = "draft"

        model.commit(.memberID, host: .ehentai)

        #expect(harness.cookie(CookieName.ipbPassHash, GalleryHost.ehentai.url).isEmpty)
        #expect(model.ehCookies.passHash.editingText == "draft")
    }

    @Test func editingCookiesUpdatesTheSession() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { AccountSettingModel() }
        model.loadCookies()
        #expect(!model.isLoggedIn)

        model.ehCookies.memberID.editingText = "1"
        model.commit(.memberID, host: .ehentai)
        #expect(!model.isLoggedIn)
        model.ehCookies.passHash.editingText = "hash"
        model.commit(.passHash, host: .ehentai)
        #expect(model.isLoggedIn)

        model.ehCookies.passHash.editingText = ""
        model.commit(.passHash, host: .ehentai)
        #expect(!model.isLoggedIn)
        #expect(model.ehCookies.passHash.value.status == .notFound)
    }

    @Test func unchangedCommitWritesNothing() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        let model = harness.make { AccountSettingModel() }
        model.loadCookies()
        let revision = harness.session.cookieRevision

        model.ehCookies.memberID.editingText = " 123 "
        model.commit(.memberID, host: .ehentai)

        #expect(harness.session.cookieRevision == revision)
        #expect(model.ehCookies.memberID.editingText == "123")
    }

    @Test func copyCookiesCopiesTheHostDescription() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        let model = harness.make { AccountSettingModel() }

        model.copyCookies(host: .ehentai)

        #expect(harness.copiedTexts.all == [#"["ipb_member_id": "123", "ipb_pass_hash": "hash"]"#])
        #expect(model.copyCount == 1)
    }

    @Test func switchingHostPersistsAndRetargetsTagsManagement() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { AccountSettingModel() }
        #expect(model.galleryHost == .ehentai)

        model.galleryHost = .exhentai

        #expect(harness.settings.galleryHost == .exhentai)
        #expect(harness.settings.galleryHostProvider.current == .exhentai)
        model.presentTagsManagement()
        #expect(model.destination == .webView(URL(string: "https://exhentai.org/mytags")!))
    }

    @Test func tagsManagementIsUnavailableWithDomainFronting() async throws {
        let harness = try await AccountHarness()
        harness.settings.bypassesSNIFiltering = true
        let model = harness.make { AccountSettingModel() }
        #expect(!model.isTagsManagementAvailable)
        model.presentTagsManagement()
        #expect(model.destination == nil)
    }

    @Test func logoutClearsAndReloadsTheFields() async throws {
        let harness = try await AccountHarness()
        harness.setLogin(on: .ehentai)
        harness.session.cookiesDidChange()
        let model = harness.make { AccountSettingModel() }
        model.loadCookies()
        #expect(model.isLoggedIn)

        await model.logout()

        #expect(!model.isLoggedIn)
        #expect(model.ehCookies.memberID.value == .empty)
        #expect(harness.diskCacheClears.count == 1)
    }
}
