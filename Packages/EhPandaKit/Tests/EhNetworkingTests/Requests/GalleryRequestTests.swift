import EhModels
import EhNetworking
import Foundation
import Testing

private typealias T = RequestTesting

@Suite struct GalleryRequestTests {
    private let ehGallery = T.url("https://e-hentai.org/g/2345678/0a1b2c3d4e/")
    private let exGallery = T.url("https://exhentai.org/g/2345678/0a1b2c3d4e/")

    @Test(arguments: GalleryHost.allCases)
    func detailKeepsTheGalleryURLHostAndAsksForAllComments(host: GalleryHost) {
        T.expectGET(
            T.builder(host).galleryDetail(galleryURL: ehGallery),
            "https://e-hentai.org/g/2345678/0a1b2c3d4e/?hc=1"
        )
        T.expectGET(
            T.builder(host).galleryDetail(galleryURL: exGallery),
            "https://exhentai.org/g/2345678/0a1b2c3d4e/?hc=1"
        )
    }

    @Test func reverseIsAPlainGET() {
        let imagePage = T.url("https://exhentai.org/s/abcdef1234/2345678-3")
        T.expectGET(T.eh.galleryReverse(url: imagePage), "https://exhentai.org/s/abcdef1234/2345678-3")
        T.expectGET(T.eh.galleryReverse(url: ehGallery), "https://e-hentai.org/g/2345678/0a1b2c3d4e/")
    }

    @Test func archiveIsAPlainGET() {
        let archive = T.url("https://exhentai.org/archiver.php?gid=2345678&token=0a1b2c3d4e")
        T.expectGET(
            T.ex.galleryArchive(archiveURL: archive),
            "https://exhentai.org/archiver.php?gid=2345678&token=0a1b2c3d4e"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func archiveFundsAlwaysReadTheEHentaiGalleryPage(host: GalleryHost) throws {
        let fromEx = try #require(T.builder(host).galleryArchiveFunds(galleryURL: exGallery))
        T.expectGET(fromEx, "https://e-hentai.org/g/2345678/0a1b2c3d4e/")
        let fromEh = try #require(T.builder(host).galleryArchiveFunds(galleryURL: ehGallery))
        T.expectGET(fromEh, "https://e-hentai.org/g/2345678/0a1b2c3d4e/")
    }

    @Test(arguments: GalleryHost.allCases)
    func torrents(host: GalleryHost) {
        let expected = T.origin(host) + "/gallerytorrents.php?gid=2345678&t=0a1b2c3d4e"
        T.expectGET(T.builder(host).galleryTorrents(gid: "2345678", token: "0a1b2c3d4e"), expected)
        #expect(T.builder(host).galleryTorrentsURL(gid: "2345678", token: "0a1b2c3d4e").absoluteString == expected)
    }

    @Test(arguments: [0, 1, 12])
    func previewAndThumbnailPagesSendPageNumber(pageNum: Int) {
        let expected = "https://exhentai.org/g/2345678/0a1b2c3d4e/?p=\(pageNum)"
        T.expectGET(T.eh.galleryPreviewURLs(galleryURL: exGallery, pageNum: pageNum), expected)
        T.expectGET(T.eh.thumbnailURLs(galleryURL: exGallery, pageNum: pageNum), expected)
    }
}

@Suite struct ReaderRequestTests {
    @Test func mpvKeysAndImagePagesArePlainGETs() {
        T.expectGET(
            T.eh.mpvKeys(mpvURL: T.url("https://exhentai.org/mpv/2345678/0a1b2c3d4e/")),
            "https://exhentai.org/mpv/2345678/0a1b2c3d4e/"
        )
        T.expectGET(
            T.eh.galleryNormalImageURL(thumbnailURL: T.url("https://e-hentai.org/s/abcdef1234/2345678-3")),
            "https://e-hentai.org/s/abcdef1234/2345678-3"
        )
    }

    @Test func refetchAddsSkipServerIdentifier() {
        T.expectGET(
            T.ex.galleryNormalImageURLRefetch(
                thumbnailURL: T.url("https://exhentai.org/s/abcdef1234/2345678-3"),
                skipServerIdentifier: "12345-430636"
            ),
            "https://exhentai.org/s/abcdef1234/2345678-3?nl=12345-430636"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func mpvImageDispatchWithoutSkipServer(host: GalleryHost) throws {
        let request = T.builder(host).galleryMPVImageURL(
            gid: 2345678, index: 3, mpvKey: "mpvkey1", mpvImageKey: "imgkey3", skipServerIdentifier: nil
        )
        T.expectJSONPOST(
            request, T.origin(host) + "/api.php",
            body: #"{"gid":2345678,"imgkey":"imgkey3","method":"imagedispatch","mpvkey":"mpvkey1","page":3}"#
        )
        let json = try T.json(request)
        #expect(json["gid"] as? Int == 2345678)
        #expect(json["page"] as? Int == 3)
        #expect(json["nl"] == nil)
    }

    @Test func mpvImageDispatchWithSkipServer() throws {
        let request = T.ex.galleryMPVImageURL(
            gid: 1, index: 10, mpvKey: "m", mpvImageKey: "i", skipServerIdentifier: "41234-55"
        )
        T.expectJSONPOST(
            request, "https://exhentai.org/api.php",
            body: #"{"gid":1,"imgkey":"i","method":"imagedispatch","mpvkey":"m","nl":"41234-55","page":10}"#
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func mpvOriginalImageURLIsRelativeToTheHost(host: GalleryHost) {
        #expect(
            T.builder(host).mpvOriginalImageURL(path: "fullimg/2345678/3/abcdef/03.jpg").absoluteString
                == T.origin(host) + "/fullimg/2345678/3/abcdef/03.jpg"
        )
    }
}
