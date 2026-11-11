import EhModels
import Foundation
import Testing
@testable import EhParser

// The archiver and torrent pages have no fixtures; these samples follow the site's markup.

private let archiverPage = """
<html><body>
<table><tr>
<td><p>Original</p><p>142.07 MiB</p><p>Free</p></td>
<td><p>1280x</p><p>56.12 MiB</p><p>1,234 GP</p></td>
<td><p>2400x</p><p>N/A</p></td>
<td><p>Nothing here</p></td>
</tr></table>
<p>12,345 GP [?] &nbsp; 67,890 Credits</p>
</body></html>
"""

struct ArchiveParserTests {
    @Test func hathArchives() throws {
        let archive = try Parser.parseGalleryArchive(doc: html(archiverPage))
        #expect(archive.hathArchives == [
            .init(resolution: .original, fileSize: "142.07 MiB", gpPrice: "Free"),
            .init(resolution: .x1280, fileSize: "56.12 MiB", gpPrice: "1,234 GP"),
            .init(resolution: .x2400, fileSize: "N/A", gpPrice: "N/A")
        ])
    }

    @Test func currentFunds() throws {
        let (galleryPoints, credits) = try Parser.parseCurrentFunds(doc: html(archiverPage))
        #expect(galleryPoints == "12345")
        #expect(credits == "67890")
    }

    @Test func archiveResponseWithAndWithoutFunds() throws {
        let withFunds = try Parser.parseGalleryArchiveResponse(doc: html(archiverPage))
        #expect(withFunds.archive.hathArchives.count == 3)
        #expect(withFunds.galleryPoints == "12345")
        #expect(withFunds.credits == "67890")

        let withoutFunds = try Parser.parseGalleryArchiveResponse(
            doc: html("<table><tr><td><p>780x</p><p>1 MiB</p><p>Free</p></td></tr></table>")
        )
        #expect(withoutFunds.archive.hathArchives.map(\.resolution) == [.x780])
        #expect(withoutFunds.galleryPoints == nil)
        #expect(withoutFunds.credits == nil)
    }

    @Test func archivePageWithoutTable() throws {
        #expect(throws: AppError.parseFailed) { try Parser.parseGalleryArchive(doc: html("<p>Nope</p>")) }
        #expect(throws: AppError.parseFailed) { try Parser.parseCurrentFunds(doc: html("<p>Nope</p>")) }
    }

    @Test func downloadCommandResponseNamesResolutionAndClient() throws {
        let doc = try html(
            #"<div id="db"><p>A 1280x resolution download has been queued for client MyClient.</p>"#
            + #"<p>Downloads should start processing within a couple of minutes.</p></div>"#
        )
        #expect(try Parser.parseDownloadCommandResponse(doc: doc) == "1280x -> MyClient.")
    }

    @Test func downloadCommandResponseForOriginal() throws {
        let doc = try html(
            #"<div id="db"><p>An original resolution download has been queued for client </p><p>Downloads soon.</p></div>"#
        )
        #expect(try Parser.parseDownloadCommandResponse(doc: doc) == "Original")
    }

    @Test func downloadCommandResponseOtherwiseVerbatim() throws {
        let doc = try html(#"<div id="db"><p>You must have a H@H client</p><p>assigned to your account.</p></div>"#)
        #expect(try Parser.parseDownloadCommandResponse(doc: doc) == "You must have a H@H client assigned to your account.")
        #expect(throws: AppError.parseFailed) { try Parser.parseDownloadCommandResponse(doc: html("<p></p>")) }
    }
}

struct TorrentParserTests {
    @Test func torrents() throws {
        let doc = try html("""
        <form method="post"><table>
        <tr><td>Posted: 2023-09-08 00:35</td><td>Size: 47.27 MiB</td><td>Seeds: 3</td><td>Peers: 1</td><td>Downloads: 120</td></tr>
        <tr><td>Uploader: someone</td></tr>
        <tr><td><a href="https://ehtracker.org/get/1/abcdef0123456789.torrent">Gallery Title.zip</a></td></tr>
        </table></form>
        <form method="post"><table><tr><td>Posted: not a date</td></tr></table></form>
        """)
        let torrents = Parser.parseGalleryTorrents(doc: doc)
        #expect(torrents.count == 1)
        let torrent = try #require(torrents.first)
        #expect(torrent.postedDate == utcDate(2023, 9, 8, 0, 35))
        #expect(torrent.fileSize == "47.27 MiB")
        #expect(torrent.seedCount == 3)
        #expect(torrent.peerCount == 1)
        #expect(torrent.downloadCount == 120)
        #expect(torrent.uploader == "someone")
        #expect(torrent.fileName == "Gallery Title.zip")
        #expect(torrent.hash == "abcdef0123456789")
        #expect(torrent.torrentURL.absoluteString == "https://ehtracker.org/get/1/abcdef0123456789.torrent")
    }
}
