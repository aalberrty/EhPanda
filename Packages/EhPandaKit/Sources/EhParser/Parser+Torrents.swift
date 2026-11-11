import EhModels
import Foundation
import Kanna

// MARK: Torrent

extension Parser {
    /// The torrents listed on a gallery's torrent page.
    public static func parseGalleryTorrents(doc: HTMLDocument) -> [GalleryTorrent] {
        doc.xpath("//form").compactMap(parseGalleryTorrent(form:))
    }

    private static func parseGalleryTorrent(form link: Kanna.XMLElement) -> GalleryTorrent? {
        var tmpPostedTime: String?
        var tmpFileSize: String?
        var tmpSeedCount: Int?
        var tmpPeerCount: Int?
        var tmpDownloadCount: Int?
        var tmpUploader: String?
        var tmpFileName: String?
        var tmpHash: String?
        var tmpTorrentURL: URL?

        for trLink in link.xpath("//tr") {
            for tdLink in trLink.xpath("//td") {
                if let tdText = tdLink.text {
                    if tdText.contains("Posted: ") {
                        tmpPostedTime = tdText.replacingOccurrences(of: "Posted: ", with: "")
                    }
                    if tdText.contains("Size: ") {
                        tmpFileSize = tdText.replacingOccurrences(of: "Size: ", with: "")
                    }
                    if tdText.contains("Seeds: ") {
                        tmpSeedCount = Int(tdText.replacingOccurrences(of: "Seeds: ", with: ""))
                    }
                    if tdText.contains("Peers: ") {
                        tmpPeerCount = Int(tdText.replacingOccurrences(of: "Peers: ", with: ""))
                    }
                    if tdText.contains("Downloads: ") {
                        tmpDownloadCount = Int(tdText.replacingOccurrences(of: "Downloads: ", with: ""))
                    }
                    if tdText.contains("Uploader: ") {
                        tmpUploader = tdText.replacingOccurrences(of: "Uploader: ", with: "")
                    }
                }
                if let aLink = tdLink.at_xpath("//a"),
                   let aHref = aLink["href"],
                   let aText = aLink.text,
                   let aURL = URL(string: aHref),
                   let range = aURL.lastPathComponent.range(of: ".torrent")
                {
                    tmpHash = String(aURL.lastPathComponent[..<range.lowerBound])
                    tmpTorrentURL = aURL
                    tmpFileName = aText
                }
            }
        }

        guard let postedTime = tmpPostedTime,
              let postedDate = try? parseDate(time: postedTime, format: DateFormat.torrent),
              let fileSize = tmpFileSize,
              let seedCount = tmpSeedCount,
              let peerCount = tmpPeerCount,
              let downloadCount = tmpDownloadCount,
              let uploader = tmpUploader,
              let fileName = tmpFileName,
              let hash = tmpHash,
              let torrentURL = tmpTorrentURL
        else { return nil }

        return GalleryTorrent(
            postedDate: postedDate,
            fileSize: fileSize,
            seedCount: seedCount,
            peerCount: peerCount,
            downloadCount: downloadCount,
            uploader: uploader,
            fileName: fileName,
            hash: hash,
            torrentURL: torrentURL
        )
    }
}
