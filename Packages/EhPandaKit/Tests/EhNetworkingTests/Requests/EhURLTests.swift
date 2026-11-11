import EhModels
import EhNetworking
import Foundation
import Testing

private typealias T = RequestTesting

@Suite struct EhURLTests {
    // MARK: App scheme

    @Test func appSchemeBecomesHTTPS() {
        let url = EhURL.resolvingAppScheme(T.url("ehpanda://e-hentai.org/g/2345678/0a1b2c3d4e/"))
        #expect(url.absoluteString == "https://e-hentai.org/g/2345678/0a1b2c3d4e/")
    }

    @Test(arguments: ["https://e-hentai.org/g/1/a/", "http://exhentai.org/", "other://x/y"])
    func otherSchemesAreUntouched(string: String) {
        #expect(EhURL.resolvingAppScheme(T.url(string)).absoluteString == string)
    }

    // MARK: Handleable

    @Test(arguments: [
        "https://e-hentai.org/g/2345678/0a1b2c3d4e/",
        "https://exhentai.org/g/2345678/0a1b2c3d4e/",
        "https://e-hentai.org/g/2345678/0a1b2c3d4e",
        "https://e-hentai.org/g/2345678/0a1b2c3d4e/?p=2#c123",
        "https://exhentai.org/s/abcdef1234/2345678-3",
        "https://e-hentai.org/s/abcdef1234/2345678-3?nl=1"
    ])
    func handleableLinks(string: String) {
        #expect(EhURL.isHandleable(T.url(string)))
    }

    @Test(arguments: [
        "https://e-hentai.org/",
        "https://e-hentai.org/g/2345678",
        "https://e-hentai.org/g/2345678/",
        "https://e-hentai.org/t/2345678/0a1b2c3d4e/",
        "https://e-hentai.org/mpv/2345678/0a1b2c3d4e/",
        "https://forums.e-hentai.org/g/2345678/0a1b2c3d4e/",
        "https://s.exhentai.org/g/2345678/0a1b2c3d4e/",
        "https://example.com/g/2345678/0a1b2c3d4e/",
        "http://e-hentai.org/g/2345678/0a1b2c3d4e/",
        "ehpanda://e-hentai.org/g/2345678/0a1b2c3d4e/",
        // Legacy matched the string, so a query mentioning the site passed; not any more.
        "https://example.com/g/2345678/0a1b2c3d4e/?from=https://e-hentai.org/"
    ])
    func unhandleableLinks(string: String) {
        #expect(!EhURL.isHandleable(T.url(string)))
    }

    // MARK: MPV

    @Test func mpvLinks() {
        #expect(EhURL.isMPVURL(T.url("https://exhentai.org/mpv/2345678/0a1b2c3d4e/")))
        #expect(EhURL.isMPVURL(T.url("https://e-hentai.org/mpv/2345678/0a1b2c3d4e/#page3")))
    }

    @Test(arguments: [
        "https://e-hentai.org/",
        "https://e-hentai.org",
        "https://e-hentai.org/g/2345678/0a1b2c3d4e/",
        "https://e-hentai.org/s/mpv/2345678-1"
    ])
    func notMPVLinks(string: String) {
        #expect(!EhURL.isMPVURL(T.url(string)))
    }

    @Test func nilIsNotMPV() {
        #expect(!EhURL.isMPVURL(nil))
    }

    // MARK: Identifiers

    @Test func galleryIDOfGalleryAndImagePage() {
        #expect(EhURL.galleryID(of: T.url("https://e-hentai.org/g/2345678/0a1b2c3d4e/")) == "2345678")
        #expect(EhURL.galleryID(of: T.url("https://exhentai.org/s/abcdef1234/2345678-3")) == "2345678")
        #expect(EhURL.galleryID(of: T.url("https://e-hentai.org/g/2345678")) == nil)
    }

    @Test func galleryIdentifiers() throws {
        let ids = try #require(EhURL.galleryIdentifiers(of: T.url("https://exhentai.org/g/2345678/0a1b2c3d4e/")))
        #expect(ids.gid == "2345678")
        #expect(ids.token == "0a1b2c3d4e")
        #expect(EhURL.galleryIdentifiers(of: T.url("https://exhentai.org/s/abcdef1234/2345678-3")) == nil)
        #expect(EhURL.galleryIdentifiers(of: T.url("https://exhentai.org/g/2345678/")) == nil)
    }

    // MARK: Analysis

    @Test(arguments: [
        ("https://e-hentai.org/g/2345678/0a1b2c3d4e/", EhLinkAnalysis(isGalleryImageURL: false)),
        ("https://exhentai.org/s/abcdef1234/2345678-7",
         EhLinkAnalysis(isGalleryImageURL: true, pageIndex: 7)),
        ("https://exhentai.org/s/abcdef1234/2345678-x", EhLinkAnalysis(isGalleryImageURL: true)),
        ("https://e-hentai.org/g/2345678/0a1b2c3d4e/#c4567890",
         EhLinkAnalysis(isGalleryImageURL: false, commentID: "4567890")),
        ("https://e-hentai.org/g/2345678/0a1b2c3d4e/?p=1#c99",
         EhLinkAnalysis(isGalleryImageURL: false, commentID: "99")),
        // The anchor is only looked for after "<token>/".
        ("https://e-hentai.org/g/2345678/0a1b2c3d4e#c99", EhLinkAnalysis(isGalleryImageURL: false)),
        ("https://e-hentai.org/", EhLinkAnalysis(isGalleryImageURL: false)),
        ("https://example.com/s/abcdef1234/2345678-7", EhLinkAnalysis(isGalleryImageURL: false))
    ])
    func analysis(string: String, expected: EhLinkAnalysis) {
        #expect(EhURL.analyze(T.url(string)) == expected)
    }

    // MARK: Hosts

    @Test func galleryHostOfURL() {
        #expect(EhURL.galleryHost(of: T.url("https://e-hentai.org/g/1/a/")) == .ehentai)
        #expect(EhURL.galleryHost(of: T.url("https://exhentai.org/")) == .exhentai)
        #expect(EhURL.galleryHost(of: T.url("https://EXHENTAI.org/")) == .exhentai)
        #expect(EhURL.galleryHost(of: T.url("https://forums.e-hentai.org/")) == nil)
        #expect(EhURL.galleryHost(of: T.url("https://s.exhentai.org/")) == nil)
    }

    @Test func replacingHostKeepsPathAndQuery() {
        let ex = T.url("https://exhentai.org/g/2345678/0a1b2c3d4e/?p=2")
        let eh = T.url("https://e-hentai.org/g/2345678/0a1b2c3d4e/?p=2")
        #expect(EhURL.replacingHost(of: ex, with: .ehentai) == eh)
        #expect(EhURL.replacingHost(of: eh, with: .exhentai) == ex)
        #expect(EhURL.replacingHost(of: eh, with: .ehentai) == eh)
    }

    // MARK: Login

    @Test func loginCompletion() {
        #expect(EhURL.isLoginCompletionURL(T.url("https://forums.e-hentai.org/index.php?act=Login&CODE=01")))
        #expect(EhURL.isLoginCompletionURL(T.url("https://forums.e-hentai.org/index.php?CODE=01")))
        #expect(!EhURL.isLoginCompletionURL(T.url("https://forums.e-hentai.org/index.php?act=Login")))
        #expect(!EhURL.isLoginCompletionURL(T.url("https://forums.e-hentai.org/index.php?act=Login&CODE=00")))
        #expect(!EhURL.isLoginCompletionURL(T.url("https://forums.e-hentai.org/index.php")))
    }
}
