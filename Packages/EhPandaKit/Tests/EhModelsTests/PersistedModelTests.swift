import EhModels
import Foundation
import Testing

/// Legacy JSON shapes: property names as keys, dates as seconds since 2001, enums with
/// associated values in Swift's synthesized form.
@Suite struct PersistedModelTests {
    static let uuid = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"

    @Test func decodesLegacyUser() throws {
        let json = """
        { "displayName": "panda", "avatarURL": "https://e-hentai.org/a.png", "apikey": "abc",
          "credits": "1,000", "galleryPoints": "2,000",
          "greeting": { "id": "\(Self.uuid)", "gainedEXP": 10, "gainedCredits": 300,
                        "updateTime": 700000000 },
          "favoriteCategories": { "0": "Favorites 0", "3": "Stories" } }
        """
        let user = try decodeJSON(User.self, json)
        #expect(user.displayName == "panda")
        #expect(user.avatarURL == URL(string: "https://e-hentai.org/a.png"))
        #expect(user.apikey == "abc" && user.credits == "1,000" && user.galleryPoints == "2,000")
        #expect(user.greeting?.id == UUID(uuidString: Self.uuid))
        #expect(user.greeting?.gainedEXP == 10 && user.greeting?.gainedCredits == 300)
        #expect(user.greeting?.gainedGP == nil)
        #expect(user.greeting?.updateTime == Date(timeIntervalSinceReferenceDate: 700000000))
        #expect(user.favoriteCategories == [0: "Favorites 0", 3: "Stories"])
        #expect(try decodeJSON(User.self, "{}") == User.empty)
    }

    @Test func userRoundTrips() throws {
        let user = User(displayName: "a", greeting: .mock, favoriteCategories: [1: "x"])
        #expect(try roundTrip(user) == user)
    }

    @Test func customFavoriteCategoryName() {
        let user = User(favoriteCategories: [0: "Favorites 0", 1: "Stories"])
        #expect(user.customFavoriteCategoryName(index: 0) == nil)
        #expect(user.customFavoriteCategoryName(index: 1) == "Stories")
        #expect(user.customFavoriteCategoryName(index: 2) == nil)
    }

    @Test func greeting() throws {
        #expect(Greeting().gainedNothing)
        #expect(!Greeting(gainedHath: 1).gainedNothing)
        #expect(try roundTrip(Greeting.mock) == .mock)
    }

    @Test func decodesLegacyQuickSearchWords() throws {
        let json = #"[{ "id": "\#(Self.uuid)", "name": "Mine", "content": "f:\"big breasts$\"" }]"#
        let words = try decodeJSON([QuickSearchWord].self, json)
        #expect(words == [QuickSearchWord(id: UUID(uuidString: Self.uuid)!, name: "Mine", content: #"f:"big breasts$""#)])
        #expect(try roundTrip(words) == words)
    }

    @Test func decodesLegacyTagTranslator() throws {
        let json = """
        { "language": { "simplifiedChinese": {} }, "hasCustomTranslations": true,
          "updatedDate": 700000000,
          "translations": { "femalebig breasts": { "namespace": "female", "key": "big breasts",
            "value": "巨乳", "description": "胸部很大", "linksString": "[维基](https://x.org)" } } }
        """
        let translator = try decodeJSON(TagTranslator.self, json)
        #expect(translator.language == .simplifiedChinese)
        #expect(translator.hasCustomTranslations)
        #expect(translator.updatedDate == Date(timeIntervalSinceReferenceDate: 700000000))
        let translation = try #require(translator.translations["femalebig breasts"])
        #expect(translation == TagTranslation(
            namespace: .female, key: "big breasts", value: "巨乳",
            description: "胸部很大", linksString: "[维基](https://x.org)"
        ))
        #expect(try roundTrip(translator) == translator)
    }

    @Test func tagTranslatorToleratesMissingKeys() throws {
        let translator = try decodeJSON(TagTranslator.self, "{}")
        #expect(translator == TagTranslator())
        #expect(translator.updatedDate == .distantPast)
    }

    @Test func translatableLanguageUsesSynthesizedForm() throws {
        let data = try JSONEncoder().encode(TranslatableLanguage.traditionalChinese)
        #expect(String(decoding: data, as: UTF8.self) == #"{"traditionalChinese":{}}"#)
    }

    @Test func decodesLegacyGalleryTags() throws {
        let json = """
        [{ "rawNamespace": "female", "contents": [
            { "rawNamespace": "female", "text": "big breasts", "isVotedUp": true, "isVotedDown": false,
              "textColor": { "red": 1, "green": 1, "blue": 1 },
              "backgroundColor": { "red": 1, "green": 0, "blue": 0 } },
            { "rawNamespace": "female", "text": "glasses", "isVotedUp": false, "isVotedDown": true },
            { "rawNamespace": "female", "text": "maid", "isVotedUp": false, "isVotedDown": false,
              "textColor": {}, "backgroundColor": {} }
        ] }]
        """
        let tags = try decodeJSON([GalleryTag].self, json)
        let contents = try #require(tags.first?.contents)
        #expect(tags.first?.namespace == .female)
        #expect(contents.map(\.text) == ["big breasts", "glasses", "maid"])
        #expect(contents[0].isVotedUp && !contents[0].isVotedDown)
        #expect(contents[0].backgroundColor == RGBColor(red: 1, green: 0, blue: 0))
        #expect(contents[1].isVotedDown && contents[1].backgroundColor == nil)
        #expect(contents[2].backgroundColor == nil)
        #expect(try roundTrip(tags) == tags)
    }

    @Test func decodesLegacyComments() throws {
        let json = """
        [{ "votedUp": true, "votedDown": false, "votable": true, "editable": false,
           "score": "+12", "author": "someone", "commentID": "42", "commentDate": 700000000,
           "contents": [
             { "id": "\(Self.uuid)", "type": 4, "text": "see " },
             { "id": "\(Self.uuid)", "type": 6, "link": "https://e-hentai.org/g/1/a/" },
             { "id": "\(Self.uuid)", "type": 1, "imgURL": "https://x.org/1.jpg",
               "secondImgURL": "https://x.org/2.jpg" }
           ] }]
        """
        let comments = try decodeJSON([GalleryComment].self, json)
        let comment = try #require(comments.first)
        #expect(comment.id == "42" && comment.author == "someone" && comment.score == "+12")
        #expect(comment.votedUp && !comment.votedDown && comment.votable && !comment.editable)
        #expect(comment.commentDate == Date(timeIntervalSinceReferenceDate: 700000000))
        #expect(comment.contents.map(\.type) == [.plainText, .singleLink, .doubleImg])
        #expect(comment.contents[2].secondImgURL == URL(string: "https://x.org/2.jpg"))
        #expect(comment.plainTextContent == "see https://e-hentai.org/g/1/a/")
        #expect(try roundTrip(comments) == comments)
    }

    @Test func decodesLegacyPreviewConfig() throws {
        #expect(try decodeJSON(PreviewConfig.self, #"{"normal":{"rows":4}}"#) == .normal(rows: 4))
        #expect(try decodeJSON(PreviewConfig.self, #"{"large":{"rows":10}}"#) == .large(rows: 10))
        #expect(try roundTrip(PreviewConfig.large(rows: 2)) == .large(rows: 2))
    }

    @Test func decodesLegacyVisibility() throws {
        #expect(try decodeJSON(GalleryVisibility.self, #"{"yes":{}}"#) == .yes)
        #expect(try decodeJSON(GalleryVisibility.self, #"{"no":{"reason":"Expunged"}}"#) == .no(reason: "Expunged"))
        #expect(try roundTrip(GalleryVisibility.no(reason: "Replaced")) == .no(reason: "Replaced"))
    }

    @Test func decodesLegacyURLMaps() throws {
        let json = #"{ "1": "https://x.org/1.jpg", "20": "https://x.org/20.jpg" }"#
        let urls = try decodeJSON([Int: URL].self, json)
        #expect(urls == [1: URL(string: "https://x.org/1.jpg")!, 20: URL(string: "https://x.org/20.jpg")!])
        #expect(try roundTrip(urls) == urls)
    }

    @Test func galleryStateRoundTrips() throws {
        let state = GalleryState(
            gid: "1", tags: [GalleryTag(rawNamespace: "temp", contents: [])], readingProgress: 3,
            previewURLs: [1: URL(string: "https://x.org/p1")!], previewConfig: .normal(rows: 4),
            imageURLs: [2: URL(string: "https://x.org/2")!]
        )
        #expect(try roundTrip(state) == state)
    }

    @Test func historyGalleryRoundTrips() throws {
        let gallery = Gallery(
            gid: "1", token: "a", title: "t", rating: 4.5, tags: [], category: .manga,
            pageCount: 3, postedDate: Date(timeIntervalSinceReferenceDate: 1), coverURL: nil,
            galleryURL: URL(string: "https://e-hentai.org/g/1/a/"), lastOpenDate: .distantPast
        )
        let decoded = try roundTrip(gallery)
        #expect(decoded.galleryURL == gallery.galleryURL && decoded.category == .manga)
        #expect(decoded.lastOpenDate == .distantPast)
    }
}
