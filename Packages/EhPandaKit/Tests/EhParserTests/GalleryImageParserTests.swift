import EhModels
import Foundation
import Testing
@testable import EhParser

struct GalleryImageURLParserTests {
    // Legacy `GalleryImageURLParserTests.testGalleryNormalImageURLParser`.
    @Test func normalImageURL() throws {
        let inputIndex = 1
        let (index, imageURL, originalImageURL) = try Parser.parseGalleryNormalImageURL(
            doc: parserFixture("Gallery/GalleryNormalImageURL.html"), index: inputIndex
        )
        #expect(index == inputIndex)
        #expect(imageURL.absoluteString == "https://akrtazd.spuqplybaxmf.hath.network:65000/h/ea42b28bceeae68f1f6adb414da61d186b3d126b-311480-1280-1920-jpg/keystamp=1694132700-fd778f8260;fileindex=132044713;xres=1280/87052610_5090394_0.jpg")
        #expect(originalImageURL?.absoluteString == "https://e-hentai.org/fullimg.php?gid=0000000&page=1&key=000000000")
    }

    // Legacy `GalleryImageURLParserTests.testSkipServerIdentifierParser`.
    @Test func skipServerIdentifier() throws {
        let identifier = try Parser.parseSkipServerIdentifier(doc: parserFixture("Gallery/GalleryNormalImageURL.html"))
        #expect(identifier == "00000-000000")
    }

    @Test func galleryURLFromImagePage() throws {
        let url = try Parser.parseGalleryURL(doc: parserFixture("Gallery/GalleryNormalImageURL.html"))
        #expect(url.absoluteString == "https://e-hentai.org/g/0000000/898683e1d1/")
    }

    @Test func renewedThumbnailURLCarriesSkipServerIdentifier() throws {
        let thumbnailURL = try #require(URL(string: "https://e-hentai.org/s/abc/0000000-1"))
        let (renewed, imageURL) = try Parser.parseRenewedThumbnailURL(
            doc: parserFixture("Gallery/GalleryNormalImageURL.html"), thumbnailURL: thumbnailURL, index: 1
        )
        #expect(renewed.absoluteString == "https://e-hentai.org/s/abc/0000000-1?nl=00000-000000")
        #expect(imageURL.absoluteString.hasSuffix("/87052610_5090394_0.jpg"))
    }

    @Test func refetchedImageURLSkipsTheStoredOne() throws {
        let stored = try #require(URL(string: "https://a.example/1.jpg"))
        let other = try #require(URL(string: "https://b.example/1.jpg"))
        let reloaded = try #require(URL(string: "https://c.example/1.jpg"))
        #expect(Parser.refetchedImageURL(first: other, reloaded: reloaded, storedImageURL: stored) == other)
        #expect(Parser.refetchedImageURL(first: stored, reloaded: reloaded, storedImageURL: stored) == reloaded)
    }

    @Test func imagePageWithoutOriginal() throws {
        let doc = try html(#"<div id="i3"><a><img id="img" src="https://h.example/1.jpg"></a></div>"#)
        let (index, imageURL, originalImageURL) = try Parser.parseGalleryNormalImageURL(doc: doc, index: 7)
        #expect(index == 7)
        #expect(imageURL.absoluteString == "https://h.example/1.jpg")
        #expect(originalImageURL == nil)
    }
}

struct GalleryPreviewParserTests {
    @Test func spriteSheetPreviewURLs() throws {
        let previews = try Parser.parsePreviewURLs(doc: parserFixture("Gallery/GalleryDetail.html"))
        #expect(previews.count == 40)
        #expect(Set(previews.keys) == Set(1...40))
        #expect(previews[1]?.absoluteString
            == "https://sunvxqrqcj.hath.network/cm/azlrrht402sk9g3kpk/3103480-0.jpg?ehpandaWidth=100&ehpandaHeight=145&ehpandaOffset=0")
    }

    @Test func previewConfigsRoundTrip() throws {
        let url = try #require(try Parser.parsePreviewURLs(doc: parserFixture("Gallery/GalleryDetail.html"))[1])
        let (plainURL, size, offset) = try #require(Parser.parsePreviewConfigs(url: url))
        #expect(plainURL.absoluteString == "https://sunvxqrqcj.hath.network/cm/azlrrht402sk9g3kpk/3103480-0.jpg")
        #expect(size.width == 100 && size.height == 145)
        #expect(offset.width == 0 && offset.height == 0)
    }

    @Test func previewConfigsNeedAllThreeItems() throws {
        let url = try #require(URL(string: "https://x.example/a.jpg?ehpandaWidth=1&ehpandaHeight=2"))
        #expect(Parser.parsePreviewConfigs(url: url) == nil)
        let combined = Parser.combinedPreviewURL(
            plainURL: try #require(URL(string: "https://x.example/a.jpg")), width: "100", height: "145", offset: "-200"
        )
        #expect(combined.absoluteString == "https://x.example/a.jpg?ehpandaWidth=100&ehpandaHeight=145&ehpandaOffset=-200")
        let (_, size, offset) = try #require(Parser.parsePreviewConfigs(url: combined))
        #expect(size.width == 100 && size.height == 145)
        #expect(offset.width == -200 && offset.height == 0)
    }

    @Test func standalonePreviewURLs() throws {
        let doc = try html(
            #"<div id="gdt"><a href="https://e-hentai.org/s/a/1-1"><div title="Page 1: a.jpg" style="background:transparent url(https://p.example/1.jpg) 0 0 no-repeat"></div></a>"#
            + #"<a href="https://e-hentai.org/s/b/1-2"><div title="Page 2: b.jpg" style="background:transparent url(https://p.example/2.jpg) 0 0 no-repeat"></div></a></div>"#
        )
        let previews = try Parser.parsePreviewURLs(doc: doc)
        #expect(previews.mapValues(\.absoluteString) == [1: "https://p.example/1.jpg", 2: "https://p.example/2.jpg"])
        let thumbnails = try Parser.parseThumbnailURLs(doc: doc)
        #expect(thumbnails.mapValues(\.absoluteString) == [1: "https://e-hentai.org/s/a/1-1", 2: "https://e-hentai.org/s/b/1-2"])
    }

    @Test func thumbnailURLs() throws {
        let thumbnails = try Parser.parseThumbnailURLs(doc: parserFixture("Gallery/GalleryDetail.html"))
        #expect(thumbnails.count == 40)
        #expect(thumbnails[1]?.absoluteString == "https://e-hentai.org/mpv/3103480/0000000000/#page1")
        #expect(thumbnails[40]?.absoluteString == "https://e-hentai.org/mpv/3103480/0000000000/#page40")
    }

    @Test func previewMode() throws {
        #expect(try Parser.parsePreviewMode(doc: parserFixture("Gallery/GalleryDetail.html")) == "gt100")
        #expect(try Parser.parsePreviewMode(doc: html(#"<div class="gt200"></div>"#)) == "gt200")
        #expect(throws: AppError.parseFailed) { try Parser.parsePreviewMode(doc: html("<p></p>")) }
    }

    @Test(arguments: [
        ("gt100", 40, PreviewConfig.normal(rows: 4)),
        ("gt100", 80, .normal(rows: 8)),
        ("gt100", 200, .normal(rows: 20)),
        ("gt100", 400, .normal(rows: 40)),
        ("gt200", 20, .large(rows: 4)),
        ("gt200", 40, .large(rows: 8)),
        ("gt200", 100, .large(rows: 20)),
        ("gt200", 200, .large(rows: 40)),
        ("gt200", 201, .large(rows: 4))
    ])
    func previewConfig(mode: String, perPage: Int, expected: PreviewConfig) throws {
        let doc = try html(#"<div class="\#(mode)"></div><p class="gpc">Showing 1 - \#(perPage) of 999 images</p>"#)
        #expect(try DetailParser.parsePreviewConfig(doc: doc) == expected)
    }

    @Test func pageIndexFromTitle() {
        #expect(Parser.parseGTX00IndexFromTitle(from: "Page 12: 012.jpg") == 12)
        #expect(Parser.parseGTX00IndexFromTitle(from: "Page 3") == 3)
        #expect(Parser.parseGTX00IndexFromTitle(from: "cover.jpg") == nil)
    }
}

struct GalleryMPVParserTests {
    // Legacy `GalleryMPVKeysParserTests.testExample`.
    @Test func mpvKeys() throws {
        let (mpvKey, mpvImageKeys) = try Parser.parseMPVKeys(doc: parserFixture("Gallery/GalleryMPVKeys.html"))
        #expect(mpvKey == "00000000000")
        #expect(mpvImageKeys.count == 194)
        #expect(Set(mpvImageKeys.keys) == Set(1...194))
    }

    @Test func mpvImageDispatchWithOriginal() throws {
        let data = Data(#"{"i":"https:\/\/h.example\/1.jpg","s":"123-456","lf":"fullimg\/1\/1\/abc\/1.jpg"}"#.utf8)
        let (imageURL, originalURL, identifier) = try Parser.parseGalleryMPVImageURL(data: data, host: .exhentai)
        #expect(imageURL.absoluteString == "https://h.example/1.jpg")
        #expect(originalURL?.absoluteString == "https://exhentai.org/fullimg/1/1/abc/1.jpg")
        #expect(identifier == "123-456")
    }

    @Test func mpvImageDispatchWithNumericIdentifier() throws {
        let data = Data(#"{"i":"https://h.example/2.jpg","s":42}"#.utf8)
        let (imageURL, originalURL, identifier) = try Parser.parseGalleryMPVImageURL(data: data, host: .ehentai)
        #expect(imageURL.absoluteString == "https://h.example/2.jpg")
        #expect(originalURL == nil)
        #expect(identifier == "42")
    }

    @Test(arguments: [
        #"{"s":"1"}"#,
        #"{"i":"https://h.example/2.jpg"}"#,
        #"{"i":"https://h.example/2.jpg","s":1.5}"#,
        "not json"
    ])
    func mpvImageDispatchFailures(json: String) {
        #expect(throws: AppError.parseFailed) {
            try Parser.parseGalleryMPVImageURL(data: Data(json.utf8), host: .ehentai)
        }
    }
}
