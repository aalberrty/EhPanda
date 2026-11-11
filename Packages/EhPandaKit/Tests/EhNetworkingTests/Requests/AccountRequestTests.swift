import EhModels
import EhNetworking
import Foundation
import Testing

private typealias T = RequestTesting

@Suite struct AccountRequestTests {
    @Test(arguments: GalleryHost.allCases)
    func loginAlwaysPostsToTheForum(host: GalleryHost) {
        T.expectFormPOST(
            T.builder(host).login(username: "panda", password: "secret"),
            "https://forums.e-hentai.org/index.php?act=Login&CODE=01",
            body: "b=d&bt=1-1&CookieDate=1&UserName=panda&PassWord=secret&ipb_login_submit=Login!"
        )
    }

    @Test func loginEscapesEveryCharacterThatWouldSplitTheForm() {
        // A password containing `&`, `=` or `+` must reach the server intact.
        T.expectFormPOST(
            T.eh.login(username: "pan da", password: "p%a&s=s+中"),
            "https://forums.e-hentai.org/index.php?act=Login&CODE=01",
            body: "b=d&bt=1-1&CookieDate=1&UserName=pan%20da&PassWord=p%25a%26s%3Ds%2B%E4%B8%AD"
                + "&ipb_login_submit=Login!"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func igneousAlwaysLoadsExHentai(host: GalleryHost) {
        T.expectGET(T.builder(host).igneous(), "https://exhentai.org/")
    }

    @Test(arguments: GalleryHost.allCases)
    func settingsPageReads(host: GalleryHost) {
        let builder = T.builder(host)
        let expected = T.origin(host) + "/uconfig.php"
        T.expectGET(builder.favoriteCategories(), expected)
        T.expectGET(builder.verifyEhProfile(), expected)
        T.expectGET(builder.ehSetting(), expected)
    }

    @Test(arguments: GalleryHost.allCases)
    func profileWithoutFieldsPostsAnEmptyForm(host: GalleryHost) {
        T.expectFormPOST(T.builder(host).ehProfile(), T.origin(host) + "/uconfig.php", body: "")
    }

    @Test func profileCreate() {
        T.expectFormPOST(
            T.eh.ehProfile(action: .create, name: "EhPanda"),
            "https://e-hentai.org/uconfig.php",
            body: "profile_action=create&profile_name=EhPanda"
        )
    }

    @Test func profileRename() {
        T.expectFormPOST(
            T.ex.ehProfile(action: .rename, name: "EhPanda (Default)", set: 2),
            "https://exhentai.org/uconfig.php",
            body: "profile_action=rename&profile_name=EhPanda%20(Default)&profile_set=2"
        )
    }

    @Test(arguments: [(EhProfileAction.delete, "delete"), (.default, "default")])
    func profileActionsOnASet(action: EhProfileAction, value: String) {
        T.expectFormPOST(
            T.eh.ehProfile(action: action, set: 3),
            "https://e-hentai.org/uconfig.php",
            body: "profile_action=\(value)&profile_set=3"
        )
    }

    @Test func profileSelectOnlySendsSet() {
        T.expectFormPOST(T.eh.ehProfile(set: 5), "https://e-hentai.org/uconfig.php", body: "profile_set=5")
    }
}

@Suite struct SubmitEhSettingRequestTests {
    @Test(arguments: GalleryHost.allCases)
    func emptySettingSendsEveryRequiredField(host: GalleryHost) {
        let favorites = (0...9).map { "favorite_\($0)=" }.joined(separator: "&")
        T.expectFormPOST(
            T.builder(host).submitEhSettingChanges(.empty),
            T.origin(host) + "/uconfig.php",
            body: "uh=0&co=-&xr=0&rx=0&ry=0&tl=0&ar=3&dm=0&pp=0&fs=1&ru=&ft=0&wt=0&tf=0&xu="
                + "&rc=1&lt=1&tr=1&tp=0&vp=0&cs=1&sc=1&tb=0&pn=0&apply=Apply&ts=1"
                + "&ct_doujinshi=0&ct_manga=0&ct_artistcg=0&ct_gamecg=0&ct_western=0&ct_non-h=0"
                + "&ct_imageset=0&ct_cosplay=0&ct_asianporn=0&ct_misc=0&" + favorites
        )
    }

    @Test func everyValueIsMapped() throws {
        var setting = EhSetting.empty
        setting.loadThroughHathSetting = .legacyNo
        setting.browsingCountry = .afghanistan
        setting.imageResolution = .x1600
        setting.imageSizeWidth = 1280.9
        setting.imageSizeHeight = 720
        setting.galleryName = .japanese
        setting.archiverBehavior = .manualSelectManualStart
        setting.displayMode = .extended
        setting.showSearchRangeIndicator = false
        setting.enableGalleryThumbnailSelector = true
        setting.disabledCategories[1] = true
        setting.disabledCategories[9] = true
        setting.favoriteCategories[0] = "My Favs"
        setting.favoritesSortOrder = .lastUpdateTime
        setting.ratingsColor = "RRGGB"
        setting.tagFilteringThreshold = -50
        setting.tagWatchingThreshold = 25
        setting.showFilteredRemovalCount = false
        setting.excludedLanguages[0] = true
        setting.excludedLanguages[3] = true
        setting.excludedLanguages[49] = true
        setting.excludedUploaders = "uploader1\nuploader2"
        setting.searchResultCount = .twoHundred
        setting.thumbnailLoadTiming = .onMouseOver
        setting.thumbnailConfigSize = .small
        setting.thumbnailConfigRows = .forty
        setting.coverScaleFactor = 150
        setting.viewportVirtualWidth = 1024
        setting.commentsSortOrder = .highestScore
        setting.commentVotesShowTiming = .onHoverOrClick
        setting.tagsSortOrder = .tagPower
        setting.galleryPageNumbering = .pageNumberAndName
        setting.useOriginalImages = true
        setting.useMultiplePageViewer = false
        setting.multiplePageViewerStyle = .alignCenterAlwaysScale
        setting.multiplePageViewerShowThumbnailPane = true

        let fields = try formFields(T.eh.submitEhSettingChanges(setting))
        let expected: [String: String] = [
            "uh": "3", "co": "AF", "xr": "4", "rx": "1280", "ry": "720", "tl": "1", "ar": "0",
            "dm": "2", "pp": "1", "fs": "0", "ru": "RRGGB", "ft": "-50", "wt": "25", "tf": "1",
            "xu": "uploader1\nuploader2", "rc": "3", "lt": "0", "tr": "3", "tp": "150", "vp": "1024",
            "cs": "2", "sc": "0", "tb": "1", "pn": "2", "apply": "Apply",
            "xn_0": "on", "ts": "2",
            "ct_doujinshi": "0", "ct_manga": "1", "ct_artistcg": "0", "ct_gamecg": "0",
            "ct_western": "0", "ct_non-h": "0", "ct_imageset": "0", "ct_cosplay": "0",
            "ct_asianporn": "0", "ct_misc": "1",
            "favorite_0": "My Favs", "favorite_1": "", "favorite_2": "", "favorite_3": "",
            "favorite_4": "", "favorite_5": "", "favorite_6": "", "favorite_7": "",
            "favorite_8": "", "favorite_9": "",
            "xl_1024": "on", "xl_1025": "on", "xl_2303": "on",
            "oi": "1", "qb": "0", "ms": "2", "mt": "0"
        ]
        #expect(fields.count == expected.count)
        #expect(Dictionary(fields, uniquingKeysWith: { first, _ in first }) == expected)
    }

    @Test(arguments: [
        (EhSetting.ThumbnailSize.auto, "0"), (.normal, "1"), (.small, "2"), (.large, nil)
    ] as [(EhSetting.ThumbnailSize, String?)])
    func thumbnailSize(size: EhSetting.ThumbnailSize, value: String?) throws {
        var setting = EhSetting.empty
        setting.thumbnailConfigSize = size
        let fields = try formFields(T.eh.submitEhSettingChanges(setting))
        #expect(fields.first { $0.0 == "ts" }?.1 == value)
    }

    @Test func optionalSettingsInverted() throws {
        var setting = EhSetting.empty
        setting.useOriginalImages = false
        setting.useMultiplePageViewer = true
        setting.multiplePageViewerStyle = .alignLeftScaleIfOverWidth
        setting.multiplePageViewerShowThumbnailPane = false
        let fields = try formFields(T.eh.submitEhSettingChanges(setting))
        let optional = fields.filter { ["oi", "qb", "ms", "mt"].contains($0.0) }
        #expect(optional.map(\.0) == ["oi", "qb", "ms", "mt"])
        #expect(optional.map(\.1) == ["0", "1", "0", "1"])
    }

    @Test func shortArraysAreSkippedInsteadOfCrashing() throws {
        let setting = EhSetting(
            ehProfiles: [], isCapableOfCreatingNewProfile: false,
            capableLoadThroughHathSetting: .anyClient, capableImageResolution: .auto,
            capableSearchResultCount: .fifty, capableThumbnailConfigRowCount: .four,
            capableThumbnailConfigSizes: [], loadThroughHathSetting: .anyClient,
            browsingCountry: .autoDetect, literalBrowsingCountry: "", imageResolution: .auto,
            imageSizeWidth: 0, imageSizeHeight: 0, galleryName: .default,
            archiverBehavior: .manualSelectManualStart, displayMode: .compact,
            showSearchRangeIndicator: true, enableGalleryThumbnailSelector: false,
            disabledCategories: [true], favoriteCategories: ["A"], favoritesSortOrder: .favoritedTime,
            ratingsColor: "", tagFilteringThreshold: 0, tagWatchingThreshold: 0,
            showFilteredRemovalCount: true, excludedLanguages: [], excludedUploaders: "",
            searchResultCount: .fifty, thumbnailLoadTiming: .onPageLoad, thumbnailConfigSize: .auto,
            thumbnailConfigRows: .four, coverScaleFactor: 0, viewportVirtualWidth: 0,
            commentsSortOrder: .oldest, commentVotesShowTiming: .always, tagsSortOrder: .alphabetical,
            galleryPageNumbering: .none
        )
        let fields = try formFields(T.eh.submitEhSettingChanges(setting))
        #expect(fields.filter { $0.0.hasPrefix("ct_") }.map(\.0) == ["ct_doujinshi"])
        #expect(fields.filter { $0.0.hasPrefix("favorite_") }.map(\.0) == ["favorite_0"])
    }

    /// Decodes a form body whose values contain no `&` or `=`.
    private func formFields(_ request: URLRequest) throws -> [(String, String)] {
        let body = try #require(T.body(request))
        return try body.split(separator: "&").map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = try #require(String(parts[0]).removingPercentEncoding)
            let value = try #require(String(parts.count > 1 ? parts[1] : "").removingPercentEncoding)
            return (name, value)
        }
    }
}
