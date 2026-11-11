import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

private let archiveURL = URL(string: "https://e-hentai.org/archiver.php?gid=2725078&token=abcdef0123")!

private let archiverTable = """
<table><tr>
<td><p>Original</p><p>142.07 MiB</p><p>Free</p></td>
<td><p>1280x</p><p>56.12 MiB</p><p>1,234 GP</p></td>
<td><p>2400x</p><p>N/A</p></td>
</tr></table>
"""
private let funds = "<p>12,345 GP [?] &nbsp; 67,890 Credits</p>"

@MainActor
@Suite struct ArchivesModelTests {
    private func makeModel(_ env: DetailEnvironment) -> ArchivesModel {
        env.with { ArchivesModel(gallery: DetailEnvironment.gallery, archiveURL: archiveURL) }
    }

    @Test func archivesAndFundsFromTheArchivePage() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.path("/archiver.php"), reply: .html("<html><body>\(archiverTable)\(funds)</body></html>"))
        let model = makeModel(env)
        await model.load()
        #expect(model.loadingState == .idle)
        #expect(model.archives.map(\.resolution) == [.original, .x1280, .x2400])
        #expect(env.userStore.galleryPoints == "12345")
        #expect(env.userStore.credits == "67890")
    }

    @Test func missingFundsAreReadThroughEHentaiForTheSameAccount() async throws {
        let env = try await DetailEnvironment()
        env.logIn()
        env.cookies.setOrEditCookie(for: GalleryHost.exhentai.url, name: "ipb_member_id", value: "1234567")
        let fundsArchiveURL = "/archiver.php"
        env.transport.on(.path(fundsArchiveURL), replies:
            .html("<html><body>\(archiverTable)</body></html>"),
            .html("<html><body>\(archiverTable)\(funds)</body></html>")
        )
        env.transport.on(.path(DetailEnvironment.detailPath), reply: .fixture("Parser/Gallery/GalleryDetail.html"))
        let model = makeModel(env)
        await model.load()
        #expect(model.archives.count == 3)
        #expect(env.userStore.galleryPoints == "12345")
        #expect(env.userStore.credits == "67890")
        #expect(env.requests("GET", path: DetailEnvironment.detailPath).count == 1)
    }

    @Test func missingFundsForDifferentAccountsAreNotFetched() async throws {
        let env = try await DetailEnvironment()
        env.logIn()
        env.transport.on(.path("/archiver.php"), reply: .html("<html><body>\(archiverTable)</body></html>"))
        let model = makeModel(env)
        await model.load()
        #expect(model.archives.count == 3)
        #expect(env.userStore.credits == nil)
        #expect(env.transport.requests.count == 1)
    }

    @Test func pageWithoutArchivesIsNotFound() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.path("/archiver.php"), reply: .html("<table><tr><td><p>Nothing</p></td></tr></table>"))
        let model = makeModel(env)
        await model.load()
        #expect(model.loadingState == .failed(.notFound))
    }

    @Test func onlyValidArchivesCanBeSelected() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.path("/archiver.php"), reply: .html("<html><body>\(archiverTable)</body></html>"))
        let model = makeModel(env)
        await model.load()
        model.select(model.archives[2])
        #expect(model.selection == nil)
        model.select(model.archives[1])
        #expect(model.selection == .x1280)
        #expect(model.selectionCount == 1)
    }

    @Test func downloadCommandReportsTheServerMessage() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.method("GET") && .path("/archiver.php"), reply: .html(archiverTable))
        env.transport.on(.method("POST") && .path("/archiver.php"), reply: .html(
            #"<div id="db"><p>A 1280x resolution download has been queued for client MyClient.</p>"#
                + #"<p>Downloads should start processing within a couple of minutes.</p></div>"#
        ))
        let model = makeModel(env)
        await model.load()
        model.sendDownloadCommand()
        #expect(model.download == nil)

        model.select(model.archives[1])
        model.sendDownloadCommand()
        #expect(model.download == .communicating)
        await pollUntil { model.download == .finished(.success(message: "1280x -> MyClient.")) }
        #expect(model.feedback?.isSuccess == true)
        let request = try #require(env.requests("POST", path: "/archiver.php").first)
        #expect(formBody(request) == "hathdl_xres=1280")

        model.dismissDownloadResult()
        #expect(model.download == nil)
    }

    @Test func knownServerErrorsAreRecognised() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.method("GET") && .path("/archiver.php"), reply: .html(archiverTable))
        env.transport.on(.method("POST") && .path("/archiver.php"), reply: .html(
            #"<div id="db"><p>Your H@H client appears to be offline. Turn it on, then try again.</p></div>"#
        ))
        let model = makeModel(env)
        await model.load()
        model.select(model.archives[0])
        model.sendDownloadCommand()
        await pollUntil { model.download == .finished(.hathClientNotOnline) }
        #expect(model.feedback?.kind == .failure)
    }
}

@MainActor
@Suite struct TorrentsModelTests {
    private let torrentPage = """
    <form method="post"><table>
    <tr><td>Posted: 2023-09-08 00:35</td><td>Size: 47.27 MiB</td><td>Seeds: 3</td><td>Peers: 1</td><td>Downloads: 120</td></tr>
    <tr><td>Uploader: someone</td></tr>
    <tr><td><a href="https://ehtracker.org/get/1/abcdef0123456789.torrent">Gallery Title.zip</a></td></tr>
    </table></form>
    """

    private func makeModel(_ env: DetailEnvironment, directory: URL) -> TorrentsModel {
        env.with { TorrentsModel(gid: DetailEnvironment.gid, token: DetailEnvironment.token, directory: directory) }
    }

    @Test func loadsAndCopiesTheMagnetLink() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.path("/gallerytorrents.php"), reply: .html(torrentPage))
        let model = makeModel(env, directory: try TestDatabase.makeTemporaryDirectory())
        await model.load()
        let torrent = try #require(model.torrents.first)
        model.copyMagnet(of: torrent)
        #expect(env.clipboard.all == ["magnet:?xt=urn:btih:abcdef0123456789"])
        #expect(model.copyCount == 1)
    }

    @Test func noTorrentsIsNotFound() async throws {
        let env = try await DetailEnvironment()
        env.transport.on(.path("/gallerytorrents.php"), reply: .html("<p>None</p>"))
        let model = makeModel(env, directory: try TestDatabase.makeTemporaryDirectory())
        await model.load()
        #expect(model.loadingState == .failed(.notFound))
    }

    @Test func torrentFileIsSavedAndShared() async throws {
        let env = try await DetailEnvironment()
        let directory = try TestDatabase.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        env.transport.on(.path("/gallerytorrents.php"), reply: .html(torrentPage))
        env.transport.on(.host("ehtracker.org"), reply: .body(Data("d4:infoe".utf8)))
        let model = makeModel(env, directory: directory)
        await model.load()
        model.shareFile(of: try #require(model.torrents.first))
        await pollUntil { model.sharedFile != nil }
        let url = try #require(model.sharedFile?.url)
        #expect(url.lastPathComponent == "abcdef0123456789.torrent")
        #expect(try Data(contentsOf: url) == Data("d4:infoe".utf8))
    }
}

@MainActor
@Suite struct GalleryInfosModelTests {
    @Test func copiesValues() async throws {
        let env = try await DetailEnvironment()
        let model = env.with { GalleryInfosModel(gallery: DetailEnvironment.gallery, detail: .preview) }
        model.copy("2725078")
        #expect(env.clipboard.all == ["2725078"])
        #expect(model.copyCount == 1)
        #expect(model.torrentURL.absoluteString.contains("gallerytorrents.php?gid=2725078&t=abcdef0123"))
    }
}
