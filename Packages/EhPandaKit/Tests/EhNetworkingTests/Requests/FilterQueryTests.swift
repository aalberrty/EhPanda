import EhModels
import EhNetworking
import Foundation
import Testing

private typealias T = RequestTesting

/// The filter's query, observed through the front page request.
@Suite struct FilterQueryTests {
    private func query(_ filter: Filter) -> String? {
        T.eh.frontpageGalleries(filter: filter).url?.query
    }

    @Test func defaultFilterSendsNothing() {
        #expect(query(Filter()) == nil)
    }

    @Test(arguments: [
        (EhModels.Category.doujinshi, 2), (.manga, 4), (.artistCG, 8), (.gameCG, 16), (.western, 512),
        (.nonH, 256), (.imageSet, 32), (.cosplay, 64), (.asianPorn, 128), (.misc, 1)
    ])
    func eachCategoryBit(category: EhModels.Category, value: Int) {
        var filter = Filter()
        filter[keyPath: Self.flag(category)] = true
        #expect(query(filter) == "f_cats=\(value)")
    }

    @Test func everyCategoryMeansNoCategoryFilter() {
        var filter = Filter()
        for category in EhModels.Category.allFiltersCases {
            filter[keyPath: Self.flag(category)] = true
        }
        #expect(query(filter) == nil)
        filter.misc = false
        #expect(query(filter) == "f_cats=1022")
    }

    private static func flag(_ category: EhModels.Category) -> WritableKeyPath<Filter, Bool> {
        switch category {
        case .doujinshi: \.doujinshi
        case .manga: \.manga
        case .artistCG: \.artistCG
        case .gameCG: \.gameCG
        case .western: \.western
        case .nonH: \.nonH
        case .imageSet: \.imageSet
        case .cosplay: \.cosplay
        case .asianPorn: \.asianPorn
        case .misc, .private: \.misc
        }
    }

    @Test func advancedOptionsAreIgnoredUnlessAdvanced() {
        var filter = Filter()
        filter.galleryDesc = true
        filter.minRatingActivated = true
        filter.minRating = 4
        filter.pageRangeActivated = true
        filter.pageLowerBound = "5"
        filter.disableTags = true
        #expect(query(filter) == nil)
    }

    @Test func advancedDefaultsSearchNameAndTags() {
        var filter = Filter()
        filter.advanced = true
        #expect(query(filter) == "advsearch=1&f_sname=on&f_stags=on")
        filter.galleryName = false
        filter.galleryTags = false
        #expect(query(filter) == "advsearch=1")
    }

    @Test func everyAdvancedOptionInOrder() {
        var filter = Filter()
        filter.manga = true
        filter.advanced = true
        filter.galleryDesc = true
        filter.torrentFilenames = true
        filter.onlyWithTorrents = true
        filter.lowPowerTags = true
        filter.expungedGalleries = true
        filter.minRatingActivated = true
        filter.minRating = 3
        filter.pageRangeActivated = true
        filter.pageLowerBound = "10"
        filter.pageUpperBound = "200"
        filter.disableLanguage = true
        filter.disableUploader = true
        filter.disableTags = true
        // Values first (categories, rating, pages), then the switches.
        #expect(query(filter) == "f_cats=4&f_srdd=3&f_spf=10&f_spt=200"
            + "&advsearch=1&f_sname=on&f_stags=on&f_sdesc=on&f_storr=on&f_sto=on&f_sdt1=on"
            + "&f_sh=on&f_sr=on&f_sp=on&f_sfl=on&f_sfu=on&f_sft=on")
    }

    @Test func downvotedTags() {
        var filter = advanced()
        filter.downvotedTags = true
        #expect(query(filter) == "advsearch=1&f_sdt2=on")
    }

    @Test(arguments: [2, 3, 4, 5])
    func minimumRating(rating: Int) {
        var filter = advanced()
        filter.minRatingActivated = true
        filter.minRating = rating
        #expect(query(filter) == "f_srdd=\(rating)&advsearch=1&f_sr=on")
    }

    @Test(arguments: [0, 1, 6])
    func minimumRatingOutOfRangeIsDropped(rating: Int) {
        var filter = advanced()
        filter.minRatingActivated = true
        filter.minRating = rating
        #expect(query(filter) == "advsearch=1")
    }

    @Test func minimumRatingNeedsActivation() {
        var filter = advanced()
        filter.minRating = 4
        #expect(query(filter) == "advsearch=1")
    }

    @Test(arguments: [
        ("5", "10", "f_spf=5&f_spt=10&"),
        ("7", "7", "f_spf=7&f_spt=7&"),
        ("5", "", "f_spf=5&"),
        ("", "8", "f_spt=8&"),
        // A parsed pair that is not a valid range sends neither bound.
        ("10", "5", ""),
        ("0", "7", ""),
        ("-1", "", ""),
        ("", "0", ""),
        ("", "", ""),
        ("abc", "x", "")
    ])
    func pageRange(lower: String, upper: String, expectedValues: String) {
        var filter = advanced()
        filter.pageRangeActivated = true
        filter.pageLowerBound = lower
        filter.pageUpperBound = upper
        #expect(query(filter) == expectedValues + "advsearch=1&f_sp=on")
    }

    @Test func pageRangeNeedsActivation() {
        var filter = advanced()
        filter.pageLowerBound = "5"
        filter.pageUpperBound = "10"
        #expect(query(filter) == "advsearch=1")
    }

    private func advanced() -> Filter {
        var filter = Filter()
        filter.advanced = true
        filter.galleryName = false
        filter.galleryTags = false
        return filter
    }
}
