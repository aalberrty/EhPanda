import EhModels
import EhTestSupport
import Foundation
import Testing
@testable import EhNetworking

struct CookieStoreTests {
    let storage = InMemoryCookieStorage()
    var store: CookieStore { CookieStore(storage: storage) }

    let eh = GalleryHost.ehentai.url
    let ex = GalleryHost.exhentai.url
    let sex = URL(string: "https://s.exhentai.org/")!

    func put(_ name: String, _ value: String, on url: URL, expiresIn: TimeInterval? = 3600, path: String = "/") {
        var properties: [HTTPCookiePropertyKey: Any] = [.name: name, .value: value, .originURL: url, .path: path]
        if let expiresIn { properties[.expires] = Date(timeIntervalSinceNow: expiresIn) }
        storage.setCookie(HTTPCookie(properties: properties)!)
    }

    func values(_ name: String, on url: URL) -> [String] {
        (storage.cookies(for: url) ?? []).filter { $0.name == name }.map(\.value)
    }

    func login(_ url: URL, memberID: String = "1", passHash: String = "hash", igneous: String? = nil) {
        put(CookieName.ipbMemberId, memberID, on: url)
        put(CookieName.ipbPassHash, passHash, on: url)
        if let igneous { put(CookieName.igneous, igneous, on: url) }
    }

    // MARK: Reading

    @Test func cookieValueStatuses() {
        put("valid", "v", on: eh)
        put("old", "v", on: eh, expiresIn: -60)
        put("session", "v", on: eh, expiresIn: nil)
        put("blank", "", on: eh)
        put(CookieName.igneous, CookieValueConstant.mystery, on: eh)

        #expect(store.cookie(named: "valid", for: eh) == CookieValue(rawValue: "v", status: .valid))
        #expect(store.cookie(named: "old", for: eh) == CookieValue(rawValue: "", status: .expired))
        #expect(store.cookie(named: "session", for: eh) == .empty)
        #expect(store.cookie(named: "blank", for: eh) == .empty)
        #expect(store.cookie(named: "missing", for: eh) == .empty)
        let mystery = store.cookie(named: CookieName.igneous, for: eh)
        #expect(mystery.status == .mystery)
        #expect(mystery.isInvalid)
        #expect(!store.cookie(named: "valid", for: eh).isInvalid)
    }

    @Test func didLoginNeedsMemberIDAndPassHash() {
        #expect(!store.didLogin)
        put(CookieName.ipbMemberId, "1", on: eh)
        #expect(!store.didLogin)
        put(CookieName.ipbPassHash, "hash", on: eh)
        #expect(store.didLogin)
    }

    @Test func didLoginOnExHentaiAlsoNeedsUsableIgneous() {
        login(ex)
        #expect(!store.didLogin)
        put(CookieName.igneous, CookieValueConstant.mystery, on: ex)
        #expect(!store.didLogin)
        put(CookieName.igneous, "real", on: ex)
        #expect(store.didLogin)
    }

    @Test func didLoginIgnoresExpiredCookies() {
        put(CookieName.ipbMemberId, "1", on: eh)
        put(CookieName.ipbPassHash, "hash", on: eh, expiresIn: -1)
        #expect(!store.didLogin)
    }

    @Test func credentialAccessors() {
        login(ex, memberID: "42", passHash: "abc", igneous: "ign")
        #expect(store.memberID(for: .exhentai) == "42")
        #expect(store.passHash(for: .exhentai) == "abc")
        #expect(store.igneous(for: .exhentai) == "ign")
        #expect(store.memberID(for: .ehentai).isEmpty)
    }

    @Test func isSameAccount() {
        #expect(!store.isSameAccount)
        login(eh, memberID: "1")
        #expect(!store.isSameAccount)
        login(ex, memberID: "2")
        #expect(!store.isSameAccount)
        login(ex, memberID: "1")
        #expect(store.isSameAccount)
    }

    @Test func shouldFetchIgneous() {
        #expect(!store.shouldFetchIgneous)
        login(ex)
        #expect(store.shouldFetchIgneous)
        put(CookieName.igneous, "ign", on: ex)
        #expect(!store.shouldFetchIgneous)
    }

    @Test func loadCookiesState() {
        login(eh, memberID: "7", passHash: "p")
        let state = store.loadCookiesState(host: .ehentai)

        #expect(state.host == .ehentai)
        #expect(state.memberID == CookieState(
            key: CookieName.ipbMemberId, value: CookieValue(rawValue: "7", status: .valid), editingText: "7"
        ))
        #expect(state.passHash.editingText == "p")
        #expect(state.igneous == CookieState(key: CookieName.igneous, value: .empty, editingText: ""))
        #expect(state.allCases.map(\.key) == [CookieName.igneous, CookieName.ipbMemberId, CookieName.ipbPassHash])
    }

    @Test func cookiesDescription() {
        #expect(store.cookiesDescription(host: .exhentai) == "[:]")
        login(ex, memberID: "1", passHash: "p", igneous: "i")
        #expect(
            store.cookiesDescription(host: .exhentai)
                == #"["igneous": "i", "ipb_member_id": "1", "ipb_pass_hash": "p"]"#
        )
    }

    // MARK: Maintenance

    @Test func removeYayOnlyTouchesExHentai() {
        put(CookieName.yay, "louder", on: ex)
        put(CookieName.yay, "louder", on: sex)
        put(CookieName.yay, "louder", on: eh)

        store.removeYay()

        #expect(values(CookieName.yay, on: ex).isEmpty)
        #expect(values(CookieName.yay, on: sex).isEmpty)
        #expect(values(CookieName.yay, on: eh) == ["louder"])
    }

    @Test func syncExCookiesCopiesLoginToImageHost() {
        login(ex, memberID: "1", passHash: "p", igneous: "i")
        put(CookieName.igneous, "stale", on: sex)

        store.syncExCookies()

        #expect(values(CookieName.ipbMemberId, on: sex) == ["1"])
        #expect(values(CookieName.ipbPassHash, on: sex) == ["p"])
        #expect(values(CookieName.igneous, on: sex) == ["i"])
    }

    @Test func ignoreOffensiveOnBothHosts() {
        put(CookieName.ignoreOffensive, "0", on: eh)

        store.ignoreOffensive()

        #expect(values(CookieName.ignoreOffensive, on: eh) == ["1"])
        #expect(values(CookieName.ignoreOffensive, on: ex) == ["1"])
    }

    @Test func fulfillAnotherHostFieldCopiesEhToEx() {
        login(eh, memberID: "1", passHash: "p")
        store.fulfillAnotherHostField()
        #expect(store.memberID(for: .exhentai) == "1")
        #expect(store.passHash(for: .exhentai) == "p")
    }

    @Test func fulfillAnotherHostFieldCopiesExToEh() {
        login(ex, memberID: "2", passHash: "q")
        put(CookieName.ipbMemberId, "stale", on: eh)
        store.fulfillAnotherHostField()
        #expect(values(CookieName.ipbMemberId, on: eh) == ["2"])
        #expect(store.passHash(for: .ehentai) == "q")
    }

    @Test func fulfillAnotherHostFieldLeavesCompleteLoginsAlone() {
        login(eh, memberID: "1")
        login(ex, memberID: "2")
        store.fulfillAnotherHostField()
        #expect(store.memberID(for: .ehentai) == "1")
        #expect(store.memberID(for: .exhentai) == "2")
    }

    @Test func clearAll() {
        login(eh)
        login(ex)
        store.clearAll()
        #expect(storage.cookies?.isEmpty == true)
    }

    // MARK: Writing

    @Test func setOrEditCookieKeepsExistingProperties() throws {
        put(CookieName.selectedProfile, "1", on: eh, path: "/uconfig.php")
        let url = eh.appendingPathComponent("uconfig.php")

        store.setOrEditCookie(for: url, name: CookieName.selectedProfile, value: "2")

        let cookies = try #require(storage.cookies)
        #expect(cookies.count == 1)
        #expect(cookies.first?.value == "2")
        #expect(cookies.first?.path == "/uconfig.php")
    }

    @Test func setOrEditCookieCreatesAYearLongCookie() throws {
        store.setOrEditCookie(for: eh, name: CookieName.selectedProfile, value: "3")

        let cookie = try #require(storage.cookies?.first)
        #expect(cookie.value == "3")
        #expect(cookie.path == "/")
        let expires = try #require(cookie.expiresDate)
        #expect(abs(expires.timeIntervalSinceNow - CookieStore.oneYear) < 60)
    }

    @Test func setCookiesWritesEveryHostURLAndTrims() {
        var state = CookiesState.empty(.exhentai)
        state.memberID = CookieState(key: CookieName.ipbMemberId, value: .empty, editingText: " 9 ")
        state.passHash = CookieState(key: CookieName.ipbPassHash, value: .empty, editingText: "h")
        state.igneous = CookieState(key: CookieName.igneous, value: .empty, editingText: "i")

        store.setCookies(state: state)

        for url in [ex, sex] {
            #expect(values(CookieName.ipbMemberId, on: url) == ["9"])
            #expect(values(CookieName.ipbPassHash, on: url) == ["h"])
            #expect(values(CookieName.igneous, on: url) == ["i"])
        }
        #expect(values(CookieName.ipbMemberId, on: eh).isEmpty)
    }

    @Test func setCookiesCanKeepSpaces() {
        var state = CookiesState.empty(.ehentai)
        state.memberID = CookieState(key: CookieName.ipbMemberId, value: .empty, editingText: " 9 ")
        state.passHash = CookieState(key: CookieName.ipbPassHash, value: .empty, editingText: "h")
        state.igneous = CookieState(key: CookieName.igneous, value: .empty, editingText: "i")

        store.setCookies(state: state, trimsSpaces: false)

        #expect(values(CookieName.ipbMemberId, on: eh) == [" 9 "])
    }

    @Test func setCredentialsFromLoginResponse() throws {
        let header = [
            "ipb_member_id=123; expires=Fri, 10-Nov-2027 00:00:00 GMT; path=/; domain=.e-hentai.org",
            "ipb_pass_hash=abc; expires=Fri, 10-Nov-2027 00:00:00 GMT; path=/; domain=.e-hentai.org",
            "igneous=ign; path=/"
        ].joined(separator: ", ")
        let response = try #require(HTTPURLResponse(
            url: eh, statusCode: 200, httpVersion: nil, headerFields: ["Set-Cookie": header]
        ))

        store.setCredentials(response: response)

        #expect(store.memberID(for: .ehentai) == "123")
        #expect(store.passHash(for: .ehentai) == "abc")
        #expect(values(CookieName.igneous, on: eh).isEmpty)
        #expect(store.memberID(for: .exhentai) == "123")
        #expect(store.passHash(for: .exhentai) == "abc")
        #expect(store.igneous(for: .exhentai) == "ign")
    }

    @Test func setCredentialsWithoutHeaderDoesNothing() throws {
        let response = try #require(HTTPURLResponse(url: eh, statusCode: 200, httpVersion: nil, headerFields: [:]))
        store.setCredentials(response: response)
        #expect(storage.cookies?.isEmpty == true)
    }

    @Test(arguments: GalleryHost.allCases)
    func setSkipServerIsScopedToImagePages(host: GalleryHost) throws {
        let response = try #require(HTTPURLResponse(
            url: host.url, statusCode: 200, httpVersion: nil,
            headerFields: ["Set-Cookie": "skipserver=12345-67890; path=/s/"]
        ))

        store.setSkipServer(response: response, host: host)

        #expect(values(CookieName.skipServer, on: host.url.appendingPathComponent("s/abc/1-1")) == ["12345-67890"])
        #expect(values(CookieName.skipServer, on: host.url).isEmpty)
    }
}
