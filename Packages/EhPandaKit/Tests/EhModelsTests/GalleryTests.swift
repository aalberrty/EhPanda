import EhModels
import Foundation
import Testing

@Suite struct GalleryTests {
    static func gallery(title: String = "", rating: Float = 0, tags: [GalleryTag] = []) -> Gallery {
        Gallery(
            gid: "1", token: "t", title: title, rating: rating, tags: tags, category: .doujinshi,
            pageCount: 1, postedDate: .distantPast, coverURL: nil, galleryURL: nil
        )
    }

    static func tag(_ namespace: String, _ texts: [String]) -> GalleryTag {
        GalleryTag(rawNamespace: namespace, contents: texts.map {
            .init(rawNamespace: namespace, text: $0, isVotedUp: false, isVotedDown: false, backgroundColor: nil)
        })
    }

    @Test func trimmedTitle() {
        let title = "(C99) [Circle (Artist)] Title 【Chinese】 {Group} 「x」 | English Title"
        #expect(Self.gallery(title: title).trimmedTitle == "Title")
        #expect(Self.gallery(title: "  Plain  ").trimmedTitle == "Plain")
    }

    @Test func language() {
        let tags = [Self.tag("language", ["translated", "chinese"])]
        #expect(Self.gallery(tags: tags).language == .chinese)
        #expect(Self.gallery().language == nil)
    }

    @Test func tagContents() {
        let tags = [Self.tag("female", ["a", "b"]), Self.tag("male", ["c"])]
        #expect(Self.gallery(tags: tags).tagContents(maximum: 0).map(\.text) == ["a", "b", "c"])
        #expect(Self.gallery(tags: tags).tagContents(maximum: 2).map(\.text) == ["a", "b"])
        #expect(Self.gallery(tags: tags).tagContents(maximum: 10).count == 3)
    }

    @Test(arguments: [(Float(3.5), 3, 1, 1), (4.0, 4, 0, 1), (0.5, 0, 1, 4), (5, 5, 0, 0)])
    func ratingStars(rating: Float, filled: Int, half: Int, empty: Int) {
        let gallery = Self.gallery(rating: rating)
        #expect(gallery.filledCount == filled)
        #expect(gallery.halfFilledCount == half)
        #expect(gallery.notFilledCount == empty)
    }

    @Test func equalityIsByGID() {
        var other = Self.gallery(title: "a")
        other.title = "b"
        #expect(other == Self.gallery(title: "a"))
        #expect(Set([other, Self.gallery()]).count == 1)
        #expect(Self.gallery().description == "Gallery(1)")
    }

    @Test func categoryLists() {
        #expect(Category.allFiltersCases.count == 10 && !Category.allFiltersCases.contains(.private))
        #expect(Category.allFavoritesCases.first == .misc && Category.allFavoritesCases.count == 10)
        #expect(!Category.allFavoritesCases.contains(.private))
        #expect(Category.allFiltersCases.map(\.filterValue).reduce(0, +) == 1023)
    }

    @Test func previewConfigBatchSize() {
        #expect(PreviewConfig.normal(rows: 4).batchSize == 40)
        #expect(PreviewConfig.normal(rows: 20).batchSize == 200)
        #expect(PreviewConfig.large(rows: 4).batchSize == 20)
    }

    @Test func archives() {
        #expect(ArchiveResolution.x1280.parameter == "1280")
        #expect(ArchiveResolution.original.parameter == "org")
        let valid = GalleryArchive.HathArchive(resolution: .x780, fileSize: "10 MB", gpPrice: "Free")
        #expect(valid.isValid && valid.id == "780x")
        #expect(!GalleryArchive.HathArchive(resolution: .x780, fileSize: "N/A", gpPrice: "Free").isValid)
        #expect(!GalleryArchive.HathArchive(resolution: .x780, fileSize: "1 MB", gpPrice: "N/A").isValid)
    }

    @Test func torrentMagnet() {
        let torrent = GalleryTorrent(
            postedDate: .distantPast, fileSize: "", seedCount: 0, peerCount: 0, downloadCount: 0,
            uploader: "", fileName: "", hash: "abc", torrentURL: URL(string: "https://x.org")!
        )
        #expect(torrent.magnetURL == "magnet:?xt=urn:btih:abc")
    }

    @Test func languageAbbreviations() {
        #expect(Language.japanese.abbreviation == "JA")
        #expect(Language.invalid.abbreviation == "N/A" && Language.other.abbreviation == "N/A")
        #expect(Language.cebuano.abbreviation == "CEB")
        #expect(Language.chinese.codes == ["zh-Hans", "zh-Hant"] && Language.thai.codes == nil)
        #expect(Language.allExcludedCases.count == 17)
    }

    @Test func toplistsAndFavorites() {
        #expect(ToplistsType.allCases.map(\.categoryIndex) == [15, 13, 12, 11])
        #expect(FavoritesType.all.index == -1 && FavoritesType.favorite7.index == 7)
        #expect(FavoritesType.getTypeFrom(index: 3) == .favorite3)
        #expect(FavoritesType.getTypeFrom(index: 42) == .all)
    }
}
