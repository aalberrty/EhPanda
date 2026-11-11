import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

struct ReaderClientTests {
    private let galleryURL = clientURL("https://e-hentai.org/g/3103480/0000000000/")
    private let pageLink = clientURL("https://e-hentai.org/s/abc123/3103480-1")
    /// The image on `ClientFixture.imagePage`.
    private let fixtureImage = "https://akrtazd.spuqplybaxmf.hath.network:65000/h/ea42b28bceeae68f1f6adb414da61d186b3d126b-311480-1280-1920-jpg/keystamp=1694132700-fd778f8260;fileindex=132044713;xres=1280/87052610_5090394_0.jpg"
    private let fixtureOriginal = "https://e-hentai.org/fullimg.php?gid=0000000&page=1&key=000000000"

    /// A viewer page reloaded through another server.
    private let reloadedPage = #"<div id="i3"><a><img id="img" src="https://other.example/1.jpg"></a></div>"#

    @Test func pageLinks() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.detail))

        let links = try await harness.client.pageLinks(galleryURL: galleryURL, pageNumber: 1)

        #expect(line(try harness.onlyRequest()) == "GET https://e-hentai.org/g/3103480/0000000000/?p=1")
        #expect(links.count == 40)
        #expect(links[40]?.absoluteString == "https://e-hentai.org/mpv/3103480/0000000000/#page40")
        #expect(EhURL.isMPVURL(links[1]))
    }

    @Test func pageImageResolvesOneViewerPage() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.imagePage))

        let image = try await harness.client.pageImage(pageLink: pageLink, index: 7)

        #expect(line(try harness.onlyRequest()) == "GET \(pageLink.absoluteString)")
        #expect(image.index == 7)
        #expect(image.imageURL.absoluteString == fixtureImage)
        #expect(image.originalImageURL?.absoluteString == fixtureOriginal)
    }

    @Test func refetchWithKnownLinkReloadsThroughAnotherServerAndStoresSkipServer() async throws {
        let harness = ClientHarness()
        harness.transport.on(.path("/s/abc123/3103480-1"), reply: .fixture(ClientFixture.imagePage))
        harness.transport.on(
            .query("nl", "00000-000000"),
            reply: .html(reloadedPage, headers: ["Set-Cookie": "skipserver=12345-67890; path=/s/; domain=e-hentai.org"])
        )

        // The first load shows the image that already failed, so the reloaded one wins.
        let image = try await harness.client.refetchPageImage(
            index: 1, pageNumber: 0, galleryURL: galleryURL, pageLink: pageLink,
            storedImageURL: clientURL(fixtureImage)
        )

        #expect(harness.requests.map(line) == [
            "GET \(pageLink.absoluteString)",
            "GET \(pageLink.absoluteString)?nl=00000-000000"
        ])
        #expect(image == PageImage(index: 1, imageURL: clientURL("https://other.example/1.jpg"), originalImageURL: nil))
        let skipServer = harness.cookies.cookie(
            named: CookieName.skipServer, for: clientURL("https://e-hentai.org/s/abc123/3103480-1")
        )
        #expect(skipServer.rawValue == "12345-67890")
        let elsewhere = harness.cookies.cookie(named: CookieName.skipServer, for: clientURL("https://e-hentai.org/g/1/"))
        #expect(elsewhere.rawValue.isEmpty)
    }

    @Test func refetchKeepsTheFirstImageWhenItIsNotTheFailedOne() async throws {
        let harness = ClientHarness()
        harness.transport.on(.path("/s/abc123/3103480-1"), reply: .fixture(ClientFixture.imagePage))
        harness.transport.on(.query("nl"), reply: .html(reloadedPage))

        let image = try await harness.client.refetchPageImage(
            index: 1, pageNumber: 0, galleryURL: galleryURL, pageLink: pageLink,
            storedImageURL: clientURL("https://failed.example/1.jpg")
        )

        #expect(image.imageURL.absoluteString == fixtureImage)
        #expect(image.originalImageURL?.absoluteString == fixtureOriginal)
        #expect(harness.requests.count == 2)
    }

    @Test func refetchWithoutLinkLooksItUpOnThePreviewPageFirst() async throws {
        let harness = ClientHarness(host: .exhentai)
        let exGallery = clientURL("https://exhentai.org/g/3103480/0000000000/")
        let exLink = "https://exhentai.org/s/def456/3103480-22"
        harness.transport.on(.path("/g/3103480/0000000000/"), reply: .html(
            #"<div id="gdt"><a href="\#(exLink)"><div title="Page 22: a.jpg" style="background:transparent url(https://p.example/1.jpg) 0 0 no-repeat"></div></a></div>"#
        ))
        harness.transport.on(.path("/s/def456/3103480-22"), reply: .fixture(ClientFixture.imagePage))
        harness.transport.on(
            .query("nl"),
            reply: .html(reloadedPage, headers: ["Set-Cookie": "skipserver=1-2; path=/s/; domain=exhentai.org"])
        )

        let image = try await harness.client.refetchPageImage(
            index: 22, pageNumber: 1, galleryURL: exGallery, pageLink: nil, storedImageURL: clientURL(fixtureImage)
        )

        #expect(harness.requests.map(line) == [
            "GET https://exhentai.org/g/3103480/0000000000/?p=1",
            "GET \(exLink)",
            "GET \(exLink)?nl=00000-000000"
        ])
        #expect(image.index == 22)
        #expect(image.imageURL.absoluteString == "https://other.example/1.jpg")
        #expect(harness.cookies.cookie(named: CookieName.skipServer, for: clientURL(exLink)).rawValue == "1-2")
    }

    @Test func refetchWhenThePreviewPageDoesNotListThePage() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.detail))

        let error = await thrownError {
            try await harness.client.refetchPageImage(
                index: 41, pageNumber: 0, galleryURL: galleryURL, pageLink: nil, storedImageURL: clientURL(fixtureImage)
            )
        }

        #expect(error as? AppError == .notFound)
        #expect(harness.requests.count == 1)
    }

    @Test func refetchStopsWhenTheViewerPageDoesNotParse() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html("<html><body>Nope</body></html>"))

        let error = await thrownError {
            try await harness.client.refetchPageImage(
                index: 1, pageNumber: 0, galleryURL: galleryURL, pageLink: pageLink, storedImageURL: clientURL(fixtureImage)
            )
        }

        #expect(error as? AppError == .parseFailed)
        #expect(harness.requests.count == 1)
    }

    @Test func refetchDoesNotStoreSkipServerWhenTheReloadFails() async throws {
        let harness = ClientHarness()
        harness.transport.on(.path("/s/abc123/3103480-1"), reply: .fixture(ClientFixture.imagePage))
        harness.transport.on(.query("nl"), reply: .error(URLError(.networkConnectionLost)))

        let error = await thrownError {
            try await harness.client.refetchPageImage(
                index: 1, pageNumber: 0, galleryURL: galleryURL, pageLink: pageLink, storedImageURL: clientURL(fixtureImage)
            )
        }

        #expect(error as? AppError == .networkingFailed)
        #expect(harness.requests.count == 2)
        #expect(harness.storage.cookies?.isEmpty == true)
    }

    @Test func mpvKeys() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.mpvKeys))
        let mpvURL = clientURL("https://e-hentai.org/mpv/3103480/0000000000/")

        let keys = try await harness.client.mpvKeys(mpvURL: mpvURL)

        #expect(line(try harness.onlyRequest()) == "GET \(mpvURL.absoluteString)")
        #expect(keys.mpvKey == "00000000000")
        #expect(Set(keys.imageKeys.keys) == Set(1...194))
    }

    @Test func mpvPageImageDispatchesOnTheCurrentHost() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .body(Data(
            #"{"i":"https:\/\/h.example\/1.jpg","s":"123-456","lf":"fullimg\/1\/1\/abc\/1.jpg"}"#.utf8
        )))

        let image = try await harness.client.mpvPageImage(
            gid: "3103480", index: 5, mpvKey: "mpv", imageKey: "img", skipServerIdentifier: "9-9"
        )

        let request = try harness.onlyRequest()
        #expect(line(request) == "POST https://exhentai.org/api.php")
        let body = try jsonBody(request)
        #expect(body["method"] as? String == "imagedispatch")
        #expect(body["gid"] as? Int == 3103480)
        #expect(body["page"] as? Int == 5)
        #expect(body["imgkey"] as? String == "img")
        #expect(body["mpvkey"] as? String == "mpv")
        #expect(body["nl"] as? String == "9-9")
        #expect(image == MPVPageImage(
            image: PageImage(
                index: 5, imageURL: clientURL("https://h.example/1.jpg"),
                originalImageURL: clientURL("https://exhentai.org/fullimg/1/1/abc/1.jpg")
            ),
            skipServerIdentifier: "123-456"
        ))
    }

    @Test func mpvPageImageWithNonNumericGIDSendsNothing() async throws {
        let harness = ClientHarness()

        let error = await thrownError {
            try await harness.client.mpvPageImage(gid: "abc", index: 1, mpvKey: "m", imageKey: "i")
        }

        #expect(error as? AppError == .unknown)
        #expect(harness.requests.isEmpty)
    }
}
