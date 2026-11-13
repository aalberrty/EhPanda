import EhFeatures
import EhModels
import Foundation
import Testing

@Suite struct HomeSectionsTests {
    // MARK: Cards

    @Test func cardsTakeTheTenLongestTitlesDeduplicatedAndAtMostSix() {
        // Titles of length 1...12; "dup" titles share a trimmed title with a longer one.
        var galleries = (1...12).map { makeHomeGallery(gid: "\($0)", title: String(repeating: "a", count: $0)) }
        galleries.append(makeHomeGallery(gid: "dup12", title: String(repeating: "a", count: 12)))
        galleries.append(makeHomeGallery(gid: "dup11", title: "[Group] " + String(repeating: "a", count: 11)))
        var generator = SplitMix64(seed: 1)

        let cards = HomeSections.cards(from: galleries, using: &generator)

        // dup11's full title is the longest, so it wins over "11"; dup12 ties with "12" and
        // comes later, so "12" wins. The first six unique trimmed titles are lengths 12...7.
        #expect(Set(cards.map(\.gid)) == ["dup11", "12", "10", "9", "8", "7"])
        #expect(cards.count == HomeSections.maximumCards)
    }

    @Test func cardsKeepFewerThanSixAndDropDuplicates() {
        let galleries = [
            makeHomeGallery(gid: "1", title: "Alpha"),
            makeHomeGallery(gid: "2", title: "Alpha"),
            makeHomeGallery(gid: "3", title: "Beta")
        ]
        var generator = SplitMix64(seed: 7)

        let cards = HomeSections.cards(from: galleries, using: &generator)

        #expect(Set(cards.map(\.gid)) == ["1", "3"])
    }

    @Test func cardShuffleIsDrivenByTheGenerator() {
        let galleries = (1...6).map { makeHomeGallery(gid: "\($0)", title: String(repeating: "a", count: $0)) }
        var first = SplitMix64(seed: 42)
        var second = SplitMix64(seed: 42)

        let once = HomeSections.cards(from: galleries, using: &first)
        let again = HomeSections.cards(from: galleries, using: &second)
        let orders = Set((0..<20).map { seed -> [String] in
            var generator = SplitMix64(seed: UInt64(seed))
            return HomeSections.cards(from: galleries, using: &generator).map(\.gid)
        })

        #expect(once.map(\.gid) == again.map(\.gid))
        #expect(orders.count > 1)
    }

    @Test func pagerStartsOnTheSecondGallery() {
        #expect(HomeSections.initialCardIndex(count: 0) == nil)
        #expect(HomeSections.initialCardIndex(count: 1) == 0)
        #expect(HomeSections.initialCardIndex(count: 2) == 1)
        #expect(HomeSections.initialCardIndex(count: 6) == 1)
    }

    @Test func pagerKeepsItsPageUntilTheGalleriesChange() {
        let ids = ["a", "b", "c"]

        #expect(HomeSections.pagerPage(current: nil, oldIDs: ids, ids: ids) == "b")
        #expect(HomeSections.pagerPage(current: "c", oldIDs: ids, ids: ids) == "c")
        #expect(HomeSections.pagerPage(current: "c", oldIDs: ids, ids: ["d", "e", "c"]) == "e")
        #expect(HomeSections.pagerPage(current: "x", oldIDs: ids, ids: ids) == "b")
        #expect(HomeSections.pagerPage(current: "c", oldIDs: ids, ids: []) == nil)
    }

    @Test func compactCardsShortenLongTitles() {
        let long = makeHomeGallery(gid: "1", title: "[Circle (Artist)] A Rather Long Gallery Title | Translated Title")
        let short = makeHomeGallery(gid: "2", title: "[Circle] Short Title | Another")

        #expect(HomeSections.cardTitle(of: long, isCompact: true) == "A Rather Long Gallery Title")
        #expect(HomeSections.cardTitle(of: long, isCompact: false) == long.title)
        #expect(HomeSections.cardTitle(of: short, isCompact: true) == short.title)
    }

    // MARK: Frontpage

    @Test func frontpageKeepsTheFirstTwentyFiveUniqueTitles() {
        var galleries = (0..<30).map { makeHomeGallery(gid: "\($0)", title: "Title \($0)") }
        galleries[3] = makeHomeGallery(gid: "3", title: "Title 1 | Alternative")

        let frontpage = HomeSections.frontpage(from: galleries)

        #expect(frontpage.count == 24)
        #expect(frontpage.map(\.gid) == (0..<25).filter { $0 != 3 }.map(String.init))
    }

    @Test func frontpageWallShowsTwoFullRows() {
        let galleries = (0..<25).map { makeHomeGallery(gid: "\($0)", title: "Title \($0)") }

        let compact = HomeSections.frontpageWall(from: galleries, columns: 3)
        let regular = HomeSections.frontpageWall(from: galleries, columns: 6)

        #expect(compact.map(\.gid) == (0..<6).map(String.init))
        #expect(regular.map(\.gid) == (0..<12).map(String.init))
    }

    @Test func frontpageWallDropsAPartialLastRowButKeepsAPartialFirstRow() {
        let galleries = (0..<5).map { makeHomeGallery(gid: "\($0)", title: "Title \($0)") }

        #expect(HomeSections.frontpageWall(from: galleries, columns: 3).map(\.gid) == ["0", "1", "2"])
        #expect(HomeSections.frontpageWall(from: Array(galleries.prefix(2)), columns: 3).map(\.gid) == ["0", "1"])
        #expect(HomeSections.frontpageWall(from: Array(galleries.prefix(3)), columns: 3).count == 3)
        #expect(HomeSections.frontpageWall(from: [], columns: 3).isEmpty)
        #expect(HomeSections.frontpageWall(from: galleries, columns: 0).isEmpty)
        #expect(HomeSections.frontpageWall(from: galleries, columns: 3, rows: 0).isEmpty)
    }

    @Test func shortTitleTrimsButNeverComesOutEmpty() {
        let bracketed = makeHomeGallery(gid: "1", title: "[Circle (Artist)] Summer Notes | Translated [English]")
        let onlyBrackets = makeHomeGallery(gid: "2", title: "[Artist] (Event)")

        #expect(HomeSections.shortTitle(of: bracketed) == "Summer Notes")
        #expect(HomeSections.shortTitle(of: onlyBrackets) == onlyBrackets.title)
    }

    // MARK: Toplists

    @Test func rankingNumbersRowsFromTheRequestedRank() {
        let galleries = (0..<5).map { makeHomeGallery(gid: "\($0)", title: "Title \($0)") }

        let first = HomeSections.ranking(galleries, ranks: 1...3)
        let second = HomeSections.ranking(galleries, ranks: 4...6)

        #expect(first.map(\.rank) == [1, 2, 3])
        #expect(first.map(\.gallery.gid) == ["0", "1", "2"])
        #expect(second.map(\.rank) == [4, 5])
        #expect(second.map(\.gallery.gid) == ["3", "4"])
        #expect(HomeSections.ranking([], ranks: 1...3).isEmpty)
    }

    @Test func everySectionIsListedOnce() {
        #expect(HomeSection.all.count == 6)
        #expect(Set(HomeSection.all).count == 6)
        #expect(HomeSection.toplists == ToplistsType.allCases.map(HomeSection.toplists))
    }
}

private func makeHomeGallery(gid: String, title: String) -> Gallery {
    Gallery(
        gid: gid, token: "t", title: title, rating: 4, tags: [], category: .doujinshi,
        uploader: nil, pageCount: 1, postedDate: Date(timeIntervalSince1970: 0),
        coverURL: nil, galleryURL: nil
    )
}

/// SplitMix64: a tiny deterministic generator for shuffles in tests.
nonisolated struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
