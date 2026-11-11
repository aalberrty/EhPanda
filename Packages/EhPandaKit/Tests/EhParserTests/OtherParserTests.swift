import EhModels
import Foundation
import Testing
@testable import EhParser

struct GreetingParserTests {
    // Legacy `GreetingParserTests.testExample`. Legacy also asserted the localized
    // `gainContent`, which is app-side now.
    @Test func greeting() throws {
        let now = utcDate(2024, 1, 2, 3, 4)
        let greeting = try Parser.parseGreeting(doc: parserFixture("Other/GalleryDetailWithGreeting.html"), now: now)
        #expect(greeting.gainedEXP == 30)
        #expect(greeting.gainedCredits == 329)
        #expect(greeting.gainedGP == nil)
        #expect(greeting.gainedHath == nil)
        #expect(greeting.updateTime == now)
        #expect(!greeting.gainedNothing)
    }

    @Test func greetingWithEveryRewardAndThousandsSeparators() throws {
        let doc = try html(
            #"<div id="eventpane"><p>It is the dawn of a new day!</p><p>You gain <strong>30</strong> EXP, "#
            + #"<strong>1,234</strong> Credits, <strong>10,000</strong> GP and <strong>11</strong> Hath!</p></div>"#
        )
        let greeting = try Parser.parseGreeting(doc: doc)
        #expect(greeting.gainedEXP == 30)
        #expect(greeting.gainedCredits == 1234)
        #expect(greeting.gainedGP == 10000)
        #expect(greeting.gainedHath == 11)
        #expect(greeting.updateTime != nil)
    }

    @Test func pageWithoutEventPane() throws {
        #expect(throws: AppError.parseFailed) {
            try Parser.parseGreeting(doc: parserFixture("Gallery/GalleryDetail.html"))
        }
    }
}

struct BanIntervalParserTests {
    // Legacy `BanIntervalParserTests.testExample`.
    @Test func ipBannedFixture() throws {
        #expect(Parser.parseBanInterval(doc: try parserFixture("Other/IPBanned.html")) == .minutes(59, seconds: 48))
    }

    @Test(arguments: [
        ("2 days and 5 hours", BanInterval.days(2, hours: 5)),
        ("2 days", .days(2, hours: nil)),
        ("3 hours and 12 minutes", .hours(3, minutes: 12)),
        ("3 hours", .hours(3, minutes: nil)),
        ("10 minutes and 7 seconds", .minutes(10, seconds: 7)),
        ("10 minutes", .minutes(10, seconds: nil)),
        ("a while", .unrecognized(content: "a while"))
    ])
    func formats(description: String, expected: BanInterval) throws {
        let doc = try html("<html><body>Your IP address has been temporarily banned. The ban expires in \(description)</body></html>")
        #expect(Parser.parseBanInterval(doc: doc) == expected)
    }

    @Test func notABanPage() throws {
        #expect(Parser.parseBanInterval(doc: try parserFixture("Gallery/GalleryDetail.html")) == nil)
    }
}

struct AccountParserTests {
    @Test func userInfo() throws {
        let doc = try html(
            #"<table class="ipbtable"><tr><td><div id="profilename">Tester</div>"#
            + #"<img src="https://forums.e-hentai.org/style_images/ambience/x.gif">"#
            + #"<img src="https://forums.e-hentai.org/uploads/av-1.png"></td></tr></table>"#
        )
        let user = try Parser.parseUserInfo(doc: doc)
        #expect(user.displayName == "Tester")
        #expect(user.avatarURL?.absoluteString == "https://forums.e-hentai.org/uploads/av-1.png")
    }

    @Test func userInfoWithoutProfile() throws {
        #expect(throws: AppError.parseFailed) { try Parser.parseUserInfo(doc: html("<p>Login</p>")) }
    }

    @Test func favoriteCategories() throws {
        let categories = try Parser.parseFavoriteCategories(doc: parserFixture("Other/EhSetting.html"))
        #expect(categories == Dictionary(uniqueKeysWithValues: (0...9).map { ($0, "Favorites \($0)") }))
    }

    @Test func profileIndex() throws {
        let response = try Parser.parseProfileIndex(doc: parserFixture("Other/EhSetting.html"))
        #expect(response == VerifyEhProfileResponse(profileValue: 2, isProfileNotFound: false))
    }

    @Test func profileIndexWithoutEhPandaProfile() throws {
        let doc = try html(#"<select name="profile_set"><option value="1" selected="selected">Default Profile</option></select>"#)
        #expect(try Parser.parseProfileIndex(doc: doc) == VerifyEhProfileResponse(profileValue: nil, isProfileNotFound: true))
        #expect(throws: AppError.parseFailed) { try Parser.parseProfileIndex(doc: html("<p></p>")) }
    }
}

struct EhSettingParserTests {
    // Legacy `EhSettingParserTests.testExample`.
    @Test func ehSetting() throws {
        let ehSetting = try Parser.parseEhSetting(doc: parserFixture("Other/EhSetting.html"))
        checkProfiles(ehSetting.ehProfiles)
        checkCapability(ehSetting)
        checkRemainingStuff(ehSetting)
        // Not asserted by legacy.
        #expect(ehSetting.isCapableOfCreatingNewProfile)
        #expect(ehSetting.enableGalleryThumbnailSelector)
    }

    private func checkProfiles(_ profiles: [EhProfile]) {
        // Legacy asserted 3 but checked only the first two; the third is "FEhViewer".
        #expect(profiles.count == 3)

        let ehProfile1 = profiles[0]
        #expect(ehProfile1.value == 1)
        #expect(ehProfile1.name == "Default Profile")
        #expect(ehProfile1.isSelected == true)
        #expect(ehProfile1.isDefault == true)

        let ehProfile2 = profiles[1]
        #expect(ehProfile2.value == 2)
        #expect(ehProfile2.name == "EhPanda")
        #expect(ehProfile2.isSelected == false)
        #expect(ehProfile2.isDefault == false)
        #expect(EhSetting.verifyEhPandaProfileName(with: ehProfile2.name))
    }

    private func checkCapability(_ ehSetting: EhSetting) {
        #expect(ehSetting.capableLoadThroughHathSetting == .legacyNo)
        #expect(ehSetting.capableLoadThroughHathSettings == EhSetting.LoadThroughHathSetting.allCases)

        #expect(ehSetting.capableImageResolution == .x2400)
        #expect(ehSetting.capableImageResolutions == EhSetting.ImageResolution.allCases)

        #expect(ehSetting.capableSearchResultCount == .oneHundred)
        #expect(ehSetting.capableSearchResultCounts == [.twentyFive, .fifty, .oneHundred])

        #expect(ehSetting.capableThumbnailConfigSizes == [.auto, .small, .normal])

        #expect(ehSetting.capableThumbnailConfigRowCount == .forty)
        #expect(ehSetting.capableThumbnailConfigRowCounts == EhSetting.ThumbnailRowCount.allCases)
    }

    private func checkRemainingStuff(_ ehSetting: EhSetting) {
        #expect(ehSetting.loadThroughHathSetting == .anyClient)
        #expect(ehSetting.browsingCountry == .autoDetect)
        #expect(ehSetting.literalBrowsingCountry == "Japan")
        #expect(ehSetting.imageResolution == .auto)
        #expect(ehSetting.imageSizeWidth == 0)
        #expect(ehSetting.imageSizeHeight == 0)
        #expect(ehSetting.galleryName == .japanese)
        #expect(ehSetting.archiverBehavior == .manualSelectManualStart)
        #expect(ehSetting.displayMode == .compact)
        #expect(ehSetting.showSearchRangeIndicator == true)
        #expect(ehSetting.disabledCategories == .init(repeating: false, count: 10))
        #expect(ehSetting.favoriteCategories == [
            "Favorites 0", "Favorites 1", "Favorites 2", "Favorites 3", "Favorites 4",
            "Favorites 5", "Favorites 6", "Favorites 7", "Favorites 8", "Favorites 9"
        ])
        #expect(ehSetting.favoritesSortOrder == .favoritedTime)
        #expect(ehSetting.ratingsColor == "")
        #expect(ehSetting.tagFilteringThreshold == 0)
        #expect(ehSetting.tagWatchingThreshold == 0)
        #expect(ehSetting.showFilteredRemovalCount == true)
        #expect(ehSetting.excludedLanguages == .init(repeating: false, count: 50))
        #expect(ehSetting.excludedUploaders == "")
        #expect(ehSetting.searchResultCount == .oneHundred)
        #expect(ehSetting.thumbnailLoadTiming == .onMouseOver)
        #expect(ehSetting.thumbnailConfigSize == .auto)
        #expect(ehSetting.thumbnailConfigRows == .four)
        #expect(ehSetting.coverScaleFactor == 100)
        #expect(ehSetting.viewportVirtualWidth == 0)
        #expect(ehSetting.commentsSortOrder == .oldest)
        #expect(ehSetting.commentVotesShowTiming == .onHoverOrClick)
        #expect(ehSetting.tagsSortOrder == .alphabetical)
        #expect(ehSetting.galleryPageNumbering == .none)
        #expect(ehSetting.useOriginalImages == false)
        #expect(ehSetting.useMultiplePageViewer == true)
        #expect(ehSetting.multiplePageViewerStyle == .alignLeftScaleIfOverWidth)
        #expect(ehSetting.multiplePageViewerShowThumbnailPane == true)
    }

    @Test func pageWithoutSettingsForm() throws {
        #expect(throws: AppError.parseFailed) { try Parser.parseEhSetting(doc: parserFixture("Gallery/GalleryDetail.html")) }
    }
}
