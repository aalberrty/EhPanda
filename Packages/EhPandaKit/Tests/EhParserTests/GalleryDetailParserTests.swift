import EhModels
import Foundation
import Testing
@testable import EhParser

struct GalleryDetailParserTests {
    // Legacy `GalleryDetailParserTests.testExample`.
    @Test func detailAndState() throws {
        let (detail, state) = try Parser.parseGalleryDetail(doc: parserFixture("Gallery/GalleryDetail.html"), gid: "2725078")
        #expect(detail.gid == "2725078")
        #expect(detail.title == "[Artist] mks")
        #expect(detail.jpnTitle == "[アーティスト] mks")
        #expect(!detail.isFavorited)
        #expect(detail.visibility == .yes)
        #expect(detail.rating == 4.5)
        #expect(detail.userRating == 0)
        #expect(detail.ratingCount == 110)
        #expect(detail.category == .nonH)
        #expect(detail.language == .japanese)
        #expect(detail.uploader == "Pokom")
        #expect(detail.coverURL?.absoluteString
            == "https://ehgt.org/03/08/0308268821e99628b05a19fa54e2fc0fa9ad8f4b-1705560-1012-1470-png_250.jpg")
        #expect(detail.archiveURL?.absoluteString == "https://e-hentai.org/archiver.php?gid=3103480&token=0000000000")
        #expect(detail.parentURL?.absoluteString == "https://e-hentai.org/g/2930572/daf4b9880d/")
        #expect(detail.favoritedCount == 591)
        #expect(detail.pageCount == 156)
        #expect(detail.sizeCount == 314.3)
        #expect(detail.sizeType == "MiB")
        #expect(detail.torrentCount == 1)
        #expect(state.tags.count == 1)
        #expect(state.previewURLs.count == 40)
        #expect(state.previewConfig == .normal(rows: 4))
        #expect(state.comments.count == 10)
    }

    /// The detail page is the gallery's first preview page: the response carries the viewer
    /// links it lists next to the thumbnails, so nobody has to request the page again for them.
    @Test func detailResponseCarriesTheFirstPreviewPage() throws {
        let doc = try parserFixture("Gallery/GalleryDetail.html")
        let response = try Parser.parseGalleryDetailResponse(doc: doc, gid: "2725078")
        #expect(response.previewPage == (try Parser.parsePreviewPage(doc: doc)))
        #expect(response.state.thumbnailURLs.count == 40)
        #expect(response.state.thumbnailURLs[1]?.absoluteString == "https://e-hentai.org/mpv/3103480/0000000000/#page1")
        #expect(response.previewPage.pageURLs == response.state.thumbnailURLs)
        #expect(response.previewPage.previewURLs == response.state.previewURLs)
    }

    @Test func postedDateAndTags() throws {
        let (detail, state) = try Parser.parseGalleryDetail(doc: parserFixture("Gallery/GalleryDetail.html"), gid: "2725078")
        // "Posted: 2024-10-27 06:20", in UTC.
        #expect(detail.postedDate == utcDate(2024, 10, 27, 6, 20))
        #expect(state.gid == "2725078")
        let tag = try #require(state.tags.first)
        #expect(tag.rawNamespace == "other")
        #expect(tag.contents == [
            GalleryTag.Content(
                rawNamespace: "other", text: "non-h imageset", isVotedUp: false, isVotedDown: false, backgroundColor: nil
            )
        ])
    }

    @Test func comments() throws {
        let comments = Parser.parseComments(doc: try parserFixture("Gallery/GalleryDetail.html"))
        #expect(comments.count == 10)

        let uploaderComment = try #require(comments.first)
        #expect(uploaderComment.commentID == "0")
        // Legacy keeps the "&nbsp; &nbsp;" that follows the author link.
        let authorSuffix = "\u{00A0} \u{00A0} "
        #expect(uploaderComment.author == "Pokom" + authorSuffix)
        #expect(uploaderComment.score == nil)
        #expect(uploaderComment.commentDate == utcDate(2024, 10, 27, 6, 20))
        #expect(!uploaderComment.votable && !uploaderComment.votedUp && !uploaderComment.votedDown)
        #expect(!uploaderComment.editable)
        #expect(uploaderComment.contents.map(\.type) == [.plainText])
        #expect(uploaderComment.contents.first?.text
            == "https://www.pixiv.net/users/750220\n\nhttps://mks.booth.pm/\nhttps://twitter.com/mks_fStD")

        let second = comments[1]
        #expect(second.commentID == "5143504")
        #expect(second.author == "Roobubba" + authorSuffix)
        #expect(second.score == "+113")
        #expect(second.commentDate == utcDate(2022, 8, 28, 7, 32))
        #expect(second.votable && !second.votedUp && !second.votedDown && !second.editable)
        #expect(second.contents.first?.text
            == "Some gorgeous scenery there. Makes a refreshing change to see some good, clean stuff.")

        #expect(comments.map(\.author).last == "黑锋血色" + authorSuffix)
        #expect(comments.map(\.score) == [nil, "+113", "+5", "+27", "+19", "+9", "+7", "+12", "+21", "+7"])
    }

    @Test func apiKey() throws {
        #expect(try Parser.parseAPIKey(doc: parserFixture("Gallery/GalleryDetail.html")) == "000000000000000000")
    }

    @Test func detailResponseBundlesAPIKeyAndGreeting() throws {
        let response = try Parser.parseGalleryDetailResponse(
            doc: parserFixture("Gallery/GalleryDetail.html"), gid: "2725078"
        )
        #expect(response.detail.title == "[Artist] mks")
        #expect(response.state.comments.count == 10)
        #expect(response.apiKey == "000000000000000000")
        #expect(response.greeting == nil)
    }

    @Test func detailPageWithGreeting() throws {
        let doc = try parserFixture("Other/GalleryDetailWithGreeting.html")
        let (detail, _) = try Parser.parseGalleryDetail(doc: doc, gid: "1")
        #expect(detail.title == "[Hinahara Emi] Himetomo [Chinese][两面包夹汉化组]")
    }

    @Test func galleryFromDetailPage() throws {
        let url = try #require(URL(string: "https://e-hentai.org/g/2725078/abcdef1234/"))
        let gallery = try #require(Parser.parseGallery(doc: parserFixture("Gallery/GalleryDetail.html"), galleryURL: url))
        #expect(gallery.gid == "2725078")
        #expect(gallery.token == "abcdef1234")
        #expect(gallery.title == "[Artist] mks")
        #expect(gallery.rating == 4.5)
        #expect(gallery.tags.isEmpty)
        #expect(gallery.category == .nonH)
        #expect(gallery.uploader == "Pokom")
        #expect(gallery.pageCount == 156)
        #expect(gallery.postedDate == utcDate(2024, 10, 27, 6, 20))
        #expect(gallery.galleryURL == url)
        #expect(gallery.coverURL?.absoluteString
            == "https://ehgt.org/03/08/0308268821e99628b05a19fa54e2fc0fa9ad8f4b-1705560-1012-1470-png_250.jpg")
    }

    @Test func galleryFromNonGalleryURLOrPage() throws {
        let shortURL = try #require(URL(string: "https://e-hentai.org/g/"))
        #expect(Parser.parseGallery(doc: try parserFixture("Gallery/GalleryDetail.html"), galleryURL: shortURL) == nil)
        let url = try #require(URL(string: "https://e-hentai.org/g/1/a/"))
        #expect(Parser.parseGallery(doc: try html("<p>nothing</p>"), galleryURL: url) == nil)
    }
}

struct GalleryDetailFailureTests {
    @Test func copyrightClaim() throws {
        let doc = try html(
            #"<div class="d"><p>This gallery is unavailable due to a copyright claim by Owner Inc.Sorry about that.</p></div>"#
        )
        #expect(throws: AppError.copyrightClaim("Owner Inc")) {
            try Parser.parseGalleryDetail(doc: doc, gid: "1")
        }
    }

    @Test func expunged() throws {
        let doc = try html(#"<div class="d"><p>This gallery has been removed or is unavailable.</p></div>"#)
        #expect(throws: AppError.expunged("This gallery has been removed or is unavailable.")) {
            try Parser.parseGalleryDetail(doc: doc, gid: "1")
        }
    }

    @Test func ipBanned() throws {
        #expect(throws: AppError.ipBanned(.minutes(59, seconds: 48))) {
            try Parser.parseGalleryDetail(doc: parserFixture("Other/IPBanned.html"), gid: "1")
        }
    }

    @Test func unrelatedPage() throws {
        #expect(throws: AppError.parseFailed) {
            try Parser.parseGalleryDetail(doc: html("<p>hello</p>"), gid: "1")
        }
    }

    @Test func archiveURLFromOnClick() throws {
        let doc = try html(
            ##"<p class="g2 gsp"><a href="#" onclick="return popUp('https://e-hentai.org/archiver.php?gid=1&amp;token=t',480,320)">Archive Download</a></p>"##
        )
        let node = try #require(doc.at_xpath("//p"))
        #expect(try Parser.parseArchiveURL(node: node).absoluteString == "https://e-hentai.org/archiver.php?gid=1&token=t")
    }

    @Test func visibilityReason() throws {
        #expect(try DetailParser.parseVisibility(value: "Yes") == .yes)
        #expect(try DetailParser.parseVisibility(value: "No (Expunged)") == .no(reason: "Expunged"))
        #expect(throws: AppError.parseFailed) { try DetailParser.parseVisibility(value: "No") }
    }
}
