import EhModels
import Foundation
import Testing

@Suite struct FilterTests {
    @Test func defaults() {
        let filter = Filter()
        #expect(filter.galleryName && filter.galleryTags)
        #expect(!filter.galleryDesc && !filter.advanced && !filter.doujinshi)
        #expect(filter.minRating == 2)
        #expect(filter.pageLowerBound.isEmpty && filter.pageUpperBound.isEmpty)
    }

    @Test func decodesLegacyFilter() throws {
        let json = """
        { "doujinshi": true, "manga": false, "artistCG": true, "gameCG": false, "western": true,
          "nonH": false, "imageSet": true, "cosplay": false, "asianPorn": true, "misc": false,
          "advanced": true, "galleryName": true, "galleryTags": false, "galleryDesc": true,
          "torrentFilenames": true, "onlyWithTorrents": true, "lowPowerTags": true,
          "downvotedTags": false, "expungedGalleries": true, "minRatingActivated": true,
          "minRating": 4, "pageRangeActivated": true, "pageLowerBound": "10",
          "pageUpperBound": "200", "disableLanguage": true, "disableUploader": false,
          "disableTags": true }
        """
        let filter = try decodeJSON(Filter.self, json)
        #expect(filter.doujinshi && filter.artistCG && filter.western && filter.imageSet && filter.asianPorn)
        #expect(!filter.manga && !filter.gameCG && !filter.nonH && !filter.cosplay && !filter.misc)
        #expect(filter.advanced && filter.galleryName && !filter.galleryTags && filter.galleryDesc)
        #expect(filter.torrentFilenames && filter.onlyWithTorrents && filter.lowPowerTags)
        #expect(!filter.downvotedTags && filter.expungedGalleries)
        #expect(filter.minRatingActivated && filter.minRating == 4)
        #expect(filter.pageRangeActivated && filter.pageLowerBound == "10" && filter.pageUpperBound == "200")
        #expect(filter.disableLanguage && !filter.disableUploader && filter.disableTags)
    }

    @Test func missingKeysUseLegacyFallbacks() throws {
        let filter = try decodeJSON(Filter.self, #"{ "manga": true }"#)
        #expect(filter.manga)
        // Legacy quirk: absent name/tags flags decode as false, unlike `Filter()`.
        #expect(!filter.galleryName && !filter.galleryTags)
        #expect(filter.minRating == 2)
    }

    @Test func roundTrips() throws {
        var filter = Filter()
        filter.cosplay = true
        filter.downvotedTags = true
        filter.pageLowerBound = "3"
        #expect(try roundTrip(filter) == filter)
    }

    @Test func lowPowerAndDownvotedTagsAreExclusive() {
        var filter = Filter()
        filter.lowPowerTags = true
        filter.downvotedTags = true
        #expect(!filter.lowPowerTags && filter.downvotedTags)
        filter.lowPowerTags = true
        #expect(filter.lowPowerTags && !filter.downvotedTags)
    }

    @Test func fixInvalidDataClearsNonNumericBounds() {
        var filter = Filter()
        filter.pageLowerBound = "abc"
        filter.pageUpperBound = "12"
        filter.fixInvalidData()
        #expect(filter.pageLowerBound.isEmpty)
        #expect(filter.pageUpperBound == "12")
    }
}
