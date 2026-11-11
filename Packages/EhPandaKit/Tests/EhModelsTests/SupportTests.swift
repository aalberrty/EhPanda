import EhModels
import Foundation
import Testing

@Suite struct SupportTests {
    @Test func pageNumber() {
        var page = PageNumber()
        #expect(page.isSinglePage)
        #expect(!page.hasNextPage())
        page.current = 1
        page.maximum = 3
        #expect(!page.isSinglePage)
        #expect(page.hasNextPage(isNumericBased: true))
        #expect(!page.hasNextPage())
        page.isNextButtonEnabled = true
        page.lastItemTimestamp = "123"
        #expect(page.hasNextPage())
        page.current = 3
        #expect(!page.hasNextPage(isNumericBased: true))
        page.resetPages()
        #expect(page == PageNumber())
    }

    @Test func appError() {
        #expect(AppError.networkingFailed.isRetryable)
        #expect(AppError.ipBanned(.minutes(5, seconds: nil)).isRetryable)
        #expect(!AppError.copyrightClaim("x").isRetryable)
        #expect(!AppError.expunged("x").isRetryable)
        #expect(AppError.parseFailed.id == "Parse Error")
    }

    @Test func loadingState() {
        #expect(LoadingState.idle.isIdle && !LoadingState.idle.isLoading)
        #expect(LoadingState.loading.isLoading && LoadingState.loading.failed == nil)
        #expect(LoadingState.failed(.notFound).failed == .notFound)
    }

    @Test func rgbColor() {
        let color = RGBColor(hex: "FF8000")
        #expect(color == RGBColor(red: 1, green: 128.0 / 255, blue: 0))
        #expect(RGBColor(hex: "FFF") == nil && RGBColor(hex: "GGGGGG") == nil)
        #expect(RGBColor(hex: "FFFFFF")?.isLight == true)
        #expect(RGBColor(hex: "000000")?.isLight == false)
        #expect(RGBColor(hex: "3377FF")?.isLight == false)
    }

    @Test func rgbColorUsesLegacyKeys() throws {
        let data = try JSONEncoder().encode(RGBColor(red: 1, green: 0, blue: 0.5))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Double]
        #expect(object == ["red": 1, "green": 0, "blue": 0.5])
    }

    @Test func ehSettingCapabilities() {
        let empty = EhSetting.empty
        let setting = EhSetting(
            ehProfiles: [
                EhProfile(value: 1, name: "Default", isSelected: false),
                EhProfile(value: 2, name: "EhPanda", isSelected: true)
            ],
            isCapableOfCreatingNewProfile: false, capableLoadThroughHathSetting: .modernNo,
            capableImageResolution: .x1280, capableSearchResultCount: .fifty,
            capableThumbnailConfigRowCount: .ten, capableThumbnailConfigSizes: [.normal],
            loadThroughHathSetting: .anyClient, browsingCountry: .japan,
            literalBrowsingCountry: "Cote D'Ivoire", imageResolution: .auto, imageSizeWidth: 0,
            imageSizeHeight: 0, galleryName: .default, archiverBehavior: .manualSelectManualStart,
            displayMode: .compact, showSearchRangeIndicator: true,
            enableGalleryThumbnailSelector: false, disabledCategories: empty.disabledCategories,
            favoriteCategories: empty.favoriteCategories, favoritesSortOrder: .lastUpdateTime,
            ratingsColor: "", tagFilteringThreshold: 0, tagWatchingThreshold: 0,
            showFilteredRemovalCount: true, excludedLanguages: empty.excludedLanguages,
            excludedUploaders: "", searchResultCount: .fifty, thumbnailLoadTiming: .onPageLoad,
            thumbnailConfigSize: .normal, thumbnailConfigRows: .ten, coverScaleFactor: 100,
            viewportVirtualWidth: 0, commentsSortOrder: .oldest, commentVotesShowTiming: .always,
            tagsSortOrder: .tagPower, galleryPageNumbering: .none
        )
        #expect(setting.capableLoadThroughHathSettings == [.anyClient, .defaultPortOnly, .modernNo])
        #expect(setting.capableImageResolutions == [.auto, .x780, .x980, .x1280])
        #expect(setting.capableSearchResultCounts == [.twentyFive, .fifty])
        #expect(setting.capableThumbnailConfigRowCounts == [.four, .ten])
        #expect(setting.ehpandaProfile?.value == 2)
        #expect(setting.ehProfiles.min()?.isDefault == true)
        #expect(setting.literalBrowsingCountryValue == .coteDIvoire)
        #expect(setting.useOriginalImages == nil)
    }

    @Test func ehSettingConstants() {
        #expect(EhSetting.empty.ehpandaProfile == nil)
        #expect(EhSetting.verifyEhPandaProfileName(with: "EhPanda (Default)"))
        #expect(!EhSetting.verifyEhPandaProfileName(with: nil))
        #expect(EhSetting.categoryNames.first == "doujinshi")
        #expect(EhSetting.categoryNames.contains("artistcg") && EhSetting.categoryNames.count == 10)
        #expect(EhSetting.languageValues.count == EhSetting.empty.excludedLanguages.count)
        #expect(EhSetting.BrowsingCountry.autoDetect.englishName == "Auto-Detect")
        #expect(EhSetting.BrowsingCountry.allCases.count == 252)
        #expect(EhSetting.BrowsingCountry(rawValue: "-") == .autoDetect)
        #expect(EhProfileAction.default.rawValue == "default")
    }
}
