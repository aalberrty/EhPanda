import EhModels
import EhNetworking
import Foundation
import Testing

private typealias T = RequestTesting

@Suite struct MiscRequestTests {
    @Test(arguments: GalleryHost.allCases)
    func greetingAlwaysUsesEHentaiNews(host: GalleryHost) {
        T.expectGET(T.builder(host).greeting(), "https://e-hentai.org/news.php")
    }

    @Test(arguments: [
        (TranslatableLanguage.english, "EhPanda-Team/EhTagTranslation_Database_EN"),
        (.japanese, "EhPanda-Team/EhTagTranslation_Database_JPN"),
        (.simplifiedChinese, "EhTagTranslation/Database"),
        (.traditionalChinese, "EhTagTranslation/Database")
    ])
    func tagTranslatorURLs(language: TranslatableLanguage, repo: String) {
        let release = "https://api.github.com/repos/\(repo)/releases/latest"
        let download = "https://github.com/\(repo)/releases/latest/download/db.raw.json"
        T.expectGET(T.ex.tagTranslatorRelease(language: language), release)
        T.expectGET(T.ex.tagTranslatorDownload(language: language), download)
        #expect(EhEndpoints.tagTranslatorRelease(language: language).absoluteString == release)
        #expect(EhEndpoints.tagTranslatorDownload(language: language).absoluteString == download)
    }

    @Test func dataIsAPlainGET() {
        T.expectGET(
            T.eh.data(url: T.url("https://ehgt.org/g/t.png?x=1")),
            "https://ehgt.org/g/t.png?x=1"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func hostEndpoints(host: GalleryHost) {
        let builder = T.builder(host)
        #expect(builder.host == host)
        #expect(builder.hostURL.absoluteString == T.origin(host) + "/")
        #expect(builder.myTagsURL.absoluteString == T.origin(host) + "/mytags")
    }

    @Test func fixedEndpoints() {
        #expect(EhEndpoints.ehentai.absoluteString == "https://e-hentai.org/")
        #expect(EhEndpoints.exhentai.absoluteString == "https://exhentai.org/")
        #expect(EhEndpoints.forum.absoluteString == "https://forums.e-hentai.org/index.php")
        #expect(EhEndpoints.login.absoluteString == "https://forums.e-hentai.org/index.php?act=Login&CODE=01")
        #expect(EhEndpoints.webLogin.absoluteString == "https://forums.e-hentai.org/index.php?act=Login")
        #expect(EhEndpoints.news.absoluteString == "https://e-hentai.org/news.php")
        #expect(EhEndpoints.toplist.absoluteString == "https://e-hentai.org/toplist.php")
    }
}
