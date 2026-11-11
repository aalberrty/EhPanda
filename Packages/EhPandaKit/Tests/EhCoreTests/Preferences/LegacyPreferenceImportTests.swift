@testable import EhCore
import EhModels
import Foundation
import Testing

@MainActor @Suite struct LegacyPreferenceImportTests {
    private struct Stores {
        let storage: PreferenceStorage
        let settings: SettingsStore
        let filters: FilterStore
        let user: UserStore

        /// Fresh stores, or new instances reading `existing`'s storage.
        @MainActor init(reloading existing: Stores? = nil) {
            storage = existing?.storage ?? .ephemeral()
            settings = SettingsStore(storage: storage)
            filters = FilterStore(storage: storage)
            user = UserStore(storage: storage)
        }

        @MainActor func run(_ blobs: LegacyPreferenceBlobs) async -> LegacyPreferenceImportReport {
            await blobs.apply(to: settings, filters: filters, user: user)
        }
    }

    /// The shape the legacy app wrote: `JSONEncoder()` output of its own structs, with the
    /// accent colour as RGB components.
    private static let legacySetting = json("""
    { "galleryHost": "ExHentai", "showsNewDawnGreeting": true, "enablesTagsExtension": true,
      "translatesTags": true, "showsTagsSearchSuggestion": false, "showsImagesInTags": true,
      "redirectsLinksToSelectedHost": false, "detectsLinksFromClipboard": true,
      "backgroundBlurRadius": 20, "autoLockPolicy": 60, "listDisplayMode": 0,
      "preferredColorScheme": 2, "accentColor": { "red": 1, "green": 0.5, "blue": 0 },
      "appIconType": 1, "showsTagsInList": true, "listTagsNumberMaximum": 10,
      "displaysJapaneseTitle": false, "readingDirection": 1, "prefetchLimit": 18,
      "enablesLandscape": true, "enablesDualPageMode": true, "exceptCover": false,
      "contentDividerHeight": 5, "maximumScaleFactor": 4, "doubleTapScaleFactor": 3,
      "bypassesSNIFiltering": false }
    """)
    private static let legacyUser = json("""
    { "displayName": "panda", "apikey": "abc", "credits": "1,000", "galleryPoints": "2,000",
      "greeting": { "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "gainedEXP": 10, "updateTime": 700000000 },
      "favoriteCategories": { "0": "Favorites 0", "3": "Stories" } }
    """)
    private static let legacyFilter = json("""
    { "doujinshi": true, "manga": true, "advanced": true, "galleryName": true, "galleryTags": true,
      "minRatingActivated": true, "minRating": 3, "pageRangeActivated": true,
      "pageLowerBound": "5", "pageUpperBound": "oops" }
    """)

    private static let complete = LegacyPreferenceBlobs(
        setting: legacySetting, user: legacyUser,
        searchFilter: legacyFilter, globalFilter: legacyFilter, watchedFilter: legacyFilter
    )

    @Test func completeImport() async throws {
        let stores = Stores()
        let report = await stores.run(Self.complete)
        #expect(report == LegacyPreferenceImportReport(imported: .all, failed: []))

        let settings = stores.settings
        #expect(settings.galleryHost == .exhentai)
        #expect(settings.translatesTags && !settings.showsTagsSearchSuggestion && settings.showsImagesInTags)
        #expect(settings.autoLockPolicy == .min1 && settings.backgroundBlurRadius == 20)
        #expect(settings.accentColor == RGBColor(red: 1, green: 0.5, blue: 0))
        #expect(settings.preferredColorScheme == .dark && settings.appIconType == .ukiyoe)
        #expect(settings.readingDirection == .rightToLeft && settings.prefetchLimit == 18)
        #expect(settings.maximumScaleFactor == 4 && settings.doubleTapScaleFactor == 3)

        #expect(stores.user.displayName == "panda" && stores.user.apikey == "abc")
        #expect(stores.user.greeting?.updateTime == Date(timeIntervalSinceReferenceDate: 700_000_000))
        #expect(stores.user.favoriteCategories == [0: "Favorites 0", 3: "Stories"])

        for range in FilterRange.allCases {
            let filter = stores.filters[range]
            #expect(filter.doujinshi && filter.manga && filter.minRating == 3)
            #expect(filter.pageLowerBound == "5" && filter.pageUpperBound == "")
        }

        // Everything reached storage.
        stores.filters.waitForPendingWrites()
        stores.user.waitForPendingWrites()
        let reloaded = Stores(reloading: stores)
        #expect(reloaded.settings.setting == settings.setting)
        #expect(reloaded.user.user == stores.user.user)
        #expect(reloaded.filters.watchedFilter == stores.filters.watchedFilter)
    }

    @Test func freshInstallImportsNothing() async {
        let stores = Stores()
        let report = await stores.run(LegacyPreferenceBlobs())
        #expect(report == LegacyPreferenceImportReport())
        #expect(stores.settings.setting == Setting())
        #expect(stores.user.user == User())
        #expect(stores.storage.storedSettingKeys.isEmpty)
        stores.user.waitForPendingWrites()
        #expect(!stores.storage.contains("user"))
    }

    @Test func partialImport() async {
        let stores = Stores()
        let report = await stores.run(LegacyPreferenceBlobs(user: Self.legacyUser, globalFilter: Self.legacyFilter))
        #expect(report.imported == [.user, .globalFilter])
        #expect(report.failed.isEmpty)
        #expect(stores.settings.setting == Setting())
        #expect(stores.filters.searchFilter == Filter() && stores.filters.globalFilter.doujinshi)
    }

    @Test func corruptBlobsDoNotStopTheOthers() async {
        let stores = Stores()
        let report = await stores.run(LegacyPreferenceBlobs(
            setting: Self.legacySetting,
            user: json(#"{"displayName": 42}"#),
            searchFilter: json("[1, 2]"),
            globalFilter: json("{ truncated"),
            watchedFilter: Self.legacyFilter
        ))
        #expect(report.imported == [.setting, .watchedFilter])
        #expect(report.failed == [.user, .searchFilter, .globalFilter])
        #expect(stores.settings.galleryHost == .exhentai)
        #expect(stores.user.user == User())
        #expect(stores.filters.searchFilter == Filter() && stores.filters.globalFilter == Filter())
        #expect(stores.filters.watchedFilter.doujinshi)
    }

    @Test func corruptSettingIsReported() async {
        let stores = Stores()
        let report = await stores.run(LegacyPreferenceBlobs(setting: json("garbage")))
        #expect(report == LegacyPreferenceImportReport(imported: [], failed: [.setting]))
        #expect(stores.settings.setting == Setting())
    }

    @Test func storedHostWinsOverTheBlob() async {
        let stores = Stores()
        stores.storage.defaults.set("E-Hentai", forKey: "galleryHost")
        _ = await stores.run(LegacyPreferenceBlobs(setting: Self.legacySetting))
        #expect(stores.settings.galleryHost == .ehentai)
        #expect(stores.settings.showsNewDawnGreeting)
    }

    @Test func blobWithoutDisplayModeKeepsTheDeviceDefault() async {
        let stores = Stores()
        stores.settings.registerDefaultListDisplayMode(.thumbnail)
        _ = await stores.run(LegacyPreferenceBlobs(setting: json(#"{"showsTagsInList": true}"#)))
        #expect(stores.settings.listDisplayMode == .thumbnail)
        #expect(stores.settings.showsTagsInList)
    }

    @Test func importedDisplayModeSurvivesALaterDeviceDefault() async {
        let stores = Stores()
        _ = await stores.run(LegacyPreferenceBlobs(setting: Self.legacySetting))
        stores.settings.registerDefaultListDisplayMode(.thumbnail)
        #expect(stores.settings.listDisplayMode == .detail)
    }
}
