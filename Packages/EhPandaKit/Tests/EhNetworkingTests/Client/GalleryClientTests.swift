import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

/// The archiver page has no fixture; this follows the site's markup.
let clientArchiverPage = """
<html><body>
<table><tr>
<td><p>Original</p><p>142.07 MiB</p><p>Free</p></td>
<td><p>1280x</p><p>56.12 MiB</p><p>1,234 GP</p></td>
</tr></table>
<p>12,345 GP [?] &nbsp; 67,890 Credits</p>
</body></html>
"""

struct GalleryClientTests {
    private let galleryURL = clientURL("https://e-hentai.org/g/3103480/0000000000/")

    @Test func galleryDetailRequestsAllCommentsAndParsesEverything() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.detail))

        let response = try await harness.client.galleryDetail(gid: "2725078", galleryURL: galleryURL)

        let request = try harness.onlyRequest()
        #expect(line(request) == "GET https://e-hentai.org/g/3103480/0000000000/?hc=1")
        #expect(response.detail.gid == "2725078")
        #expect(response.detail.title == "[Artist] mks")
        #expect(response.state.comments.count == 10)
        #expect(response.state.previewURLs.count == 40)
        #expect(!response.apiKey.isEmpty)
        #expect(response.greeting == nil)
    }

    @Test func galleryDetailWithGreeting() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.detailWithGreeting))

        let response = try await harness.client.galleryDetail(gid: "1", galleryURL: galleryURL)

        #expect(response.greeting?.gainedEXP == 30)
    }

    @Test func galleryDetailRecoversFromInvalidUTF8() async throws {
        let harness = ClientHarness()
        var data = try Fixture.data(ClientFixture.detail)
        let titleRange = try #require(data.range(of: Data("[Artist] mks".utf8)))
        data.insert(contentsOf: [0xFF, 0xFE], at: titleRange.lowerBound)
        harness.transport.on(.any, reply: .body(data))

        let response = try await harness.client.galleryDetail(gid: "2725078", galleryURL: galleryURL)

        #expect(response.detail.title.hasSuffix("[Artist] mks"))
    }

    @Test func galleryDetailOfBannedIP() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ipBanned))

        let error = await thrownError { try await harness.client.galleryDetail(gid: "1", galleryURL: galleryURL) }

        #expect(error as? AppError == .ipBanned(.minutes(59, seconds: 48)))
    }

    @Test func galleryFromGalleryLinkLoadsItOnce() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.detail))

        let gallery = try await harness.client.gallery(from: galleryURL)

        #expect(line(try harness.onlyRequest()) == "GET https://e-hentai.org/g/3103480/0000000000/")
        #expect(gallery.gid == "3103480")
        #expect(gallery.token == "0000000000")
        #expect(gallery.title == "[Artist] mks")
        #expect(gallery.galleryURL == galleryURL)
    }

    @Test func galleryFromImagePageLinkChainsTwoRequests() async throws {
        let harness = ClientHarness()
        harness.transport.on(.path("/s/abc123/0000000-3"), reply: .fixture(ClientFixture.imagePage))
        harness.transport.on(.path("/g/0000000/898683e1d1/"), reply: .fixture(ClientFixture.detail))

        let gallery = try await harness.client.gallery(from: clientURL("https://e-hentai.org/s/abc123/0000000-3"))

        #expect(harness.requests.map(line) == [
            "GET https://e-hentai.org/s/abc123/0000000-3",
            "GET https://e-hentai.org/g/0000000/898683e1d1/"
        ])
        #expect(gallery.gid == "0000000")
        #expect(gallery.token == "898683e1d1")
        #expect(gallery.title == "[Artist] mks")
    }

    @Test func galleryFromLinkWhosePageIsNotAGallery() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html("<html><body><p>Nothing</p></body></html>"))

        let error = await thrownError { try await harness.client.gallery(from: galleryURL) }

        #expect(error as? AppError == .parseFailed)
    }

    @Test func archiveWithFunds() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html(clientArchiverPage))
        let archiveURL = clientURL("https://e-hentai.org/archiver.php?gid=3103480&token=0000000000")

        let info = try await harness.client.archive(archiveURL: archiveURL)

        #expect(line(try harness.onlyRequest()) == "GET \(archiveURL.absoluteString)")
        #expect(info.archive.hathArchives.map(\.resolution) == [.original, .x1280])
        #expect(info.funds == GalleryFunds(galleryPoints: "12345", credits: "67890"))
    }

    @Test func archiveWithoutFunds() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html("<table><tr><td><p>780x</p><p>1 MiB</p><p>Free</p></td></tr></table>"))

        let info = try await harness.client.archive(archiveURL: clientURL("https://e-hentai.org/archiver.php"))

        #expect(info.funds == nil)
        #expect(info.archive.hathArchives.count == 1)
    }

    @Test func archiveFundsReadsTheGalleryOnEhentaiThenItsArchivePage() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.path("/g/3103480/0000000000/"), reply: .fixture(ClientFixture.detail))
        harness.transport.on(.path("/archiver.php"), reply: .html(clientArchiverPage))

        let funds = try await harness.client.archiveFunds(
            galleryURL: clientURL("https://exhentai.org/g/3103480/0000000000/")
        )

        #expect(harness.requests.map(line) == [
            "GET https://e-hentai.org/g/3103480/0000000000/",
            "GET https://e-hentai.org/archiver.php?gid=3103480&token=0000000000"
        ])
        #expect(funds == GalleryFunds(galleryPoints: "12345", credits: "67890"))
    }

    @Test func archiveFundsStopsWhenTheArchivePageFails() async throws {
        let harness = ClientHarness()
        harness.transport.on(.path("/g/3103480/0000000000/"), reply: .fixture(ClientFixture.detail))
        harness.transport.on(.path("/archiver.php"), reply: .error(URLError(.timedOut)))

        let error = await thrownError { try await harness.client.archiveFunds(galleryURL: galleryURL) }

        #expect(error as? AppError == .networkingFailed)
        #expect(harness.requests.count == 2)
    }

    @Test func archiveFundsStopsWhenTheGalleryPageDoesNotParse() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html("<html><body><p>Nothing</p></body></html>"))

        let error = await thrownError { try await harness.client.archiveFunds(galleryURL: galleryURL) }

        #expect(error as? AppError == .parseFailed)
        #expect(harness.requests.count == 1)
    }

    @Test func archiveFundsOfBannedIP() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ipBanned))

        let error = await thrownError { try await harness.client.archiveFunds(galleryURL: galleryURL) }

        #expect(error as? AppError == .ipBanned(.minutes(59, seconds: 48)))
        #expect(harness.requests.count == 1)
    }

    @Test func sendDownloadCommandPostsTheResolutionParameter() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html(
            #"<div id="db"><p>A 1280x resolution download has been queued for client MyClient.</p>"#
                + #"<p>Downloads should start processing within a couple of minutes.</p></div>"#
        ))
        let archiveURL = clientURL("https://e-hentai.org/archiver.php?gid=1&token=t")

        let message = try await harness.client.sendDownloadCommand(archiveURL: archiveURL, resolution: .x1280)

        let request = try harness.onlyRequest()
        #expect(line(request) == "POST \(archiveURL.absoluteString)")
        #expect(request.httpBody == harness.builder.sendDownloadCommand(archiveURL: archiveURL, resolution: "1280").httpBody)
        #expect(message == "1280x -> MyClient.")
    }

    @Test func torrents() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .html("""
        <form method="post"><table>
        <tr><td>Posted: 2023-09-08 00:35</td><td>Size: 47.27 MiB</td><td>Seeds: 3</td><td>Peers: 1</td><td>Downloads: 120</td></tr>
        <tr><td>Uploader: someone</td></tr>
        <tr><td><a href="https://ehtracker.org/get/1/abcdef0123456789.torrent">Gallery Title.zip</a></td></tr>
        </table></form>
        """))

        let torrents = try await harness.client.torrents(gid: "1", token: "t")

        #expect(line(try harness.onlyRequest()) == "GET https://exhentai.org/gallerytorrents.php?gid=1&t=t")
        #expect(torrents.map(\.hash) == ["abcdef0123456789"])
    }

    @Test func previewURLs() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.detail))

        let previews = try await harness.client.previewURLs(galleryURL: galleryURL, pageNumber: 2)

        #expect(line(try harness.onlyRequest()) == "GET https://e-hentai.org/g/3103480/0000000000/?p=2")
        #expect(Set(previews.keys) == Set(1...40))
    }

    @Test func dataReturnsTheBodyAsIs() async throws {
        let harness = ClientHarness()
        let bytes = Data([0, 1, 2, 3])
        harness.transport.on(.any, reply: .body(bytes))
        let url = clientURL("https://ehtracker.org/get/1/abc.torrent")

        #expect(try await harness.client.data(from: url) == bytes)
        #expect(line(try harness.onlyRequest()) == "GET https://ehtracker.org/get/1/abc.torrent")
    }
}
