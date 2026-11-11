import EhModels
import Foundation
import Testing
@testable import EhParser

/// Port of legacy `ListParserTestType`.
enum ListFixture: String, CaseIterable, CustomTestStringConvertible {
    case frontPageMinimalList = "FrontPageMinimalList"
    case frontPageMinimalPlusList = "FrontPageMinimalPlusList"
    case frontPageCompactList = "FrontPageCompactList"
    case frontPageExtendedList = "FrontPageExtendedList"
    case frontPageThumbnailList = "FrontPageThumbnailList"
    case watchedMinimalList = "WatchedMinimalList"
    case watchedMinimalPlusList = "WatchedMinimalPlusList"
    case watchedCompactList = "WatchedCompactList"
    case watchedExtendedList = "WatchedExtendedList"
    case watchedThumbnailList = "WatchedThumbnailList"
    case popularMinimalList = "PopularMinimalList"
    case popularMinimalPlusList = "PopularMinimalPlusList"
    case popularCompactList = "PopularCompactList"
    case popularExtendedList = "PopularExtendedList"
    case popularThumbnailList = "PopularThumbnailList"
    case favoritesMinimalList = "FavoritesMinimalList"
    case favoritesMinimalPlusList = "FavoritesMinimalPlusList"
    case favoritesCompactList = "FavoritesCompactList"
    case favoritesExtendedList = "FavoritesExtendedList"
    case favoritesThumbnailList = "FavoritesThumbnailList"
    case toplistsCompactList = "ToplistsCompactList"

    var testDescription: String { rawValue }
    var path: String { "List/\(rawValue).html" }

    var assertCount: Int {
        self == .toplistsCompactList ? 50 : 100
    }

    var hasUploader: Bool {
        switch self {
        case .frontPageMinimalList, .frontPageMinimalPlusList, .frontPageCompactList, .frontPageExtendedList,
             .watchedMinimalList, .watchedMinimalPlusList, .watchedCompactList, .watchedExtendedList,
             .popularMinimalList, .popularMinimalPlusList, .popularCompactList, .popularExtendedList,
             .toplistsCompactList:
            true
        case .frontPageThumbnailList, .watchedThumbnailList, .popularThumbnailList, .favoritesThumbnailList,
             .favoritesMinimalList, .favoritesMinimalPlusList, .favoritesCompactList, .favoritesExtendedList:
            false
        }
    }
}

struct ListParserTests {
    // Legacy `ListParserTests.testExample`.
    @Test(arguments: ListFixture.allCases)
    func galleryAndUploaderCounts(fixture: ListFixture) throws {
        let galleries = try Parser.parseGalleries(doc: parserFixture(fixture.path))
        let uploaders = galleries.compactMap(\.uploader).filter { !$0.isEmpty }
        #expect(galleries.count == fixture.assertCount)
        if fixture.hasUploader {
            #expect(uploaders.count == fixture.assertCount)
        }
    }

    @Test(arguments: [
        ListFixture.frontPageMinimalList, .frontPageMinimalPlusList, .frontPageCompactList,
        .frontPageExtendedList, .frontPageThumbnailList
    ])
    func frontPageFirstGalleryInEveryDisplayMode(fixture: ListFixture) throws {
        let gallery = try #require(try Parser.parseGalleries(doc: parserFixture(fixture.path)).first)
        #expect(gallery.gid == "2668617")
        #expect(gallery.token == "2f0bbb38f9")
        #expect(gallery.title == "[ROM宅 (ROM)] せめぱん3 (ドラゴンボールGT) [DL版]")
        #expect(gallery.rating == 0)
        #expect(gallery.category == .doujinshi)
        #expect(gallery.pageCount == 48)
        #expect(gallery.postedDate == utcDate(2023, 9, 8, 0, 35))
        #expect(gallery.coverURL?.absoluteString
            == "https://ehgt.org/78/50/7850409de81adcf7a0e7086bcf009f95794089fa-483855-661-920-jpg_250.jpg")
        #expect(gallery.galleryURL?.absoluteString == "https://e-hentai.org/g/2668617/2f0bbb38f9/")
        #expect(gallery.uploader == (fixture == .frontPageThumbnailList ? nil : "hobohobo"))

        let tags = gallery.tags.map { "\($0.rawNamespace):\($0.contents.map(\.text).joined(separator: ","))" }
        switch fixture {
        case .frontPageCompactList, .frontPageExtendedList:
            #expect(tags == ["group:romtaku", "artist:rom", "other:full color"])
        default:
            // Minimal never parses tags; in Minimal+ and Thumbnail this gallery shows none.
            #expect(tags.isEmpty)
        }
    }

    @Test func minimalPlusParsesTagsButMinimalDoesNot() throws {
        let minimal = try Parser.parseGalleries(doc: parserFixture(ListFixture.frontPageMinimalList.path))
        let minimalPlus = try Parser.parseGalleries(doc: parserFixture(ListFixture.frontPageMinimalPlusList.path))
        #expect(minimal.allSatisfy { $0.tags.isEmpty })
        #expect(minimalPlus.flatMap(\.tags).flatMap(\.contents).count(where: { $0.backgroundColor != nil }) == 5)
    }

    @Test func watchedTagKeepsItsHighlightColour() throws {
        let gallery = try #require(
            try Parser.parseGalleries(doc: parserFixture(ListFixture.watchedExtendedList.path)).first
        )
        #expect(gallery.title == "[SweetEdda (ろき)] SweetEdda vol.11 悪の組織編2 細胞怪人リクオール [英訳]")
        #expect(gallery.uploader == "TGE7")
        #expect(gallery.rating == 4.5)
        let group = try #require(gallery.tags.first { $0.rawNamespace == "group" })
        let content = try #require(group.contents.first)
        #expect(content.text == "sweetedda")
        // style="…background:radial-gradient(#1357df,#3377FF)…"
        #expect(content.backgroundColor == RGBColor(red: 0x13 / 255, green: 0x57 / 255, blue: 0xDF / 255))
        let language = try #require(gallery.tags.first { $0.rawNamespace == "language" })
        #expect(language.contents.map(\.text) == ["english", "translated"])
        #expect(language.contents.allSatisfy { $0.backgroundColor == nil && !$0.isVotedUp && !$0.isVotedDown })
    }

    @Test func toplistsFirstGallery() throws {
        let gallery = try #require(
            try Parser.parseGalleries(doc: parserFixture(ListFixture.toplistsCompactList.path)).first
        )
        #expect(gallery.gid == "596447")
        #expect(gallery.token == "3894f02c20")
        #expect(gallery.title == "[LemonFont] Shapeshifter Part 1-3")
        #expect(gallery.rating == 5)
        #expect(gallery.category == .western)
        #expect(gallery.uploader == "Project_Demise")
        #expect(gallery.pageCount == 345)
        #expect(gallery.postedDate == utcDate(2013, 5, 27, 7, 47))
    }

    @Test func favoritesFirstGallery() throws {
        let gallery = try #require(
            try Parser.parseGalleries(doc: parserFixture(ListFixture.favoritesCompactList.path)).first
        )
        #expect(gallery.gid == "2636342")
        #expect(gallery.title == "Miku and Others made by AI [AI Generated]")
        #expect(gallery.rating == 4.5)
        #expect(gallery.category == .misc)
        #expect(gallery.pageCount == 632)
        #expect(gallery.tags.map(\.rawNamespace) == ["parody"])
        #expect(gallery.tags.first?.contents.count == 12)
    }

    @Test func ipBannedPageThrowsBanInterval() throws {
        #expect(throws: AppError.ipBanned(.minutes(59, seconds: 48))) {
            try Parser.parseGalleries(doc: parserFixture("Other/IPBanned.html"))
        }
    }

    @Test func emptyPageWithoutBanReturnsNoGalleries() throws {
        #expect(try Parser.parseGalleries(doc: html("<html><body><p>No hits found</p></body></html>")).isEmpty)
    }
}

struct ListPagingParserTests {
    @Test func timestampPaging() throws {
        let pageNumber = Parser.parsePageNum(doc: try parserFixture(ListFixture.frontPageCompactList.path))
        #expect(pageNumber == PageNumber(lastItemTimestamp: "2668517", isNextButtonEnabled: true))
    }

    @Test func favoritesTimestampKeepsTheLastDashComponent() throws {
        // The next link is `next=1452536-1610434311`.
        let pageNumber = Parser.parsePageNum(doc: try parserFixture(ListFixture.favoritesCompactList.path))
        #expect(pageNumber == PageNumber(lastItemTimestamp: "1610434311", isNextButtonEnabled: true))
    }

    @Test func numberedPaging() throws {
        let pageNumber = Parser.parsePageNum(doc: try parserFixture(ListFixture.toplistsCompactList.path))
        #expect(pageNumber == PageNumber(current: 0, maximum: 199))
    }

    @Test func pageWithoutNavigation() throws {
        let pageNumber = Parser.parsePageNum(doc: try parserFixture(ListFixture.popularCompactList.path))
        #expect(pageNumber == PageNumber(isNextButtonEnabled: false))
    }

    @Test func searchNavWithoutNextLink() throws {
        let doc = try html(#"<div class="searchnav"><a href="?prev=1">&lt; Prev</a></div>"#)
        #expect(Parser.parsePageNum(doc: doc) == PageNumber(lastItemTimestamp: nil, isNextButtonEnabled: false))
    }

    @Test func numberedPagingWithRangeInCurrentCell() throws {
        let doc = try html(
            #"<table class="ptt"><tr><td class="ptds"><a>3-4</a></td><td><a>1</a></td><td><a>7</a></td>"#
            + #"<td><a>&gt;</a></td></tr></table>"#
        )
        #expect(Parser.parsePageNum(doc: doc) == PageNumber(current: 3, maximum: 6))
    }

    @Test func favoritesSortOrderFromToggle() throws {
        let posted = try html(##"<div class="ido"><div><div><a href="#">Use Posted</a></div></div></div>"##)
        let favorited = try html(##"<div class="ido"><div><div><a href="#">Use Favorited</a></div></div></div>"##)
        #expect(Parser.parseFavoritesSortOrder(doc: posted) == .favoritedTime)
        #expect(Parser.parseFavoritesSortOrder(doc: favorited) == .lastUpdateTime)
    }

    @Test func favoritesFixtureHasNoSortOrderToggle() throws {
        #expect(Parser.parseFavoritesSortOrder(doc: try parserFixture(ListFixture.favoritesCompactList.path)) == nil)
    }
}
