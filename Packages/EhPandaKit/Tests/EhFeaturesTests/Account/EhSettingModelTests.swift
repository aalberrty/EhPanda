@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@MainActor @Suite struct EhSettingModelTests {
    private func loadedModel(_ harness: AccountHarness) async -> EhSettingModel {
        harness.transport.on(.settingsPage, reply: AccountFixture.settings)
        let model = harness.make { EhSettingModel() }
        await model.loadIfNeeded()
        return model
    }

    // MARK: Loading

    @Test func loadSelectsTheReportedProfile() async throws {
        let harness = try await AccountHarness()
        let model = await loadedModel(harness)

        #expect(model.loadingState == .idle)
        #expect(model.setting?.ehProfiles.map(\.value) == [1, 2, 3])
        #expect(model.selectedProfile?.value == 1)
        #expect(model.editingProfileName == "Default Profile")
        #expect(!model.isSubmitDisabled)
    }

    @Test func loadOnlyOnce() async throws {
        let harness = try await AccountHarness()
        let model = await loadedModel(harness)
        await model.loadIfNeeded()
        #expect(harness.requests("GET", path: "/uconfig.php").count == 1)
        _ = model
    }

    @Test func loadFailureCanBeRetried() async throws {
        let harness = try await AccountHarness()
        harness.transport.on(.settingsPage, replies: .error(URLError(.timedOut)), AccountFixture.settings)
        let model = harness.make { EhSettingModel() }

        await model.loadIfNeeded()
        #expect(model.loadingState == .failed(.networkingFailed))
        #expect(model.setting == nil)
        #expect(model.isSubmitDisabled)

        await model.load()
        #expect(model.loadingState == .idle)
        #expect(model.setting != nil)
    }

    @Test func pageWithoutASelectedProfileFallsBackToTheFirst() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { EhSettingModel() }
        let profiles = [EhProfile(value: 1, name: "Default", isSelected: false), EhProfile(value: 4, name: "Other", isSelected: false)]
        let setting = EhSetting(copying: .empty, profiles: profiles)

        model.apply(setting)
        #expect(model.selectedProfile?.value == 1)
        #expect(model.editingProfileName == "Default")

        model.apply(EhSetting(copying: .empty, profiles: []))
        #expect(model.selectedProfile == nil)
        #expect(model.editingProfileName.isEmpty)
        await model.renameSelectedProfile()
        await model.deleteSelectedProfile()
        #expect(harness.transport.requests.isEmpty)
    }

    // MARK: Submit

    @Test func submitPostsTheFormAndAppliesTheResponse() async throws {
        let harness = try await AccountHarness()
        let model = await loadedModel(harness)
        harness.transport.on(.settingsPost, reply: AccountFixture.settings)
        model.setting?.excludedUploaders = "someone"

        await model.submit()

        let posts = harness.requests("POST", path: "/uconfig.php")
        #expect(posts.count == 1)
        #expect(AccountHarness.body(of: posts[0]).contains("xu=someone"))
        #expect(model.submittingState == .idle)
        #expect(model.setting?.excludedUploaders != "someone")
    }

    @Test func submitFailureKeepsTheEdits() async throws {
        let harness = try await AccountHarness()
        let model = await loadedModel(harness)
        harness.transport.on(.settingsPost, reply: .error(URLError(.timedOut)))
        model.setting?.ratingsColor = "RRGGB"

        await model.submit()

        #expect(model.submittingState == .failed(.networkingFailed))
        #expect(model.setting?.ratingsColor == "RRGGB")
    }

    // MARK: Profiles

    @Test func profileActionsPostTheirForm() async throws {
        let harness = try await AccountHarness()
        let model = await loadedModel(harness)
        harness.transport.on(.settingsPost, reply: AccountFixture.settings)

        await model.selectProfile(1)
        #expect(harness.requests("POST", path: "/uconfig.php").isEmpty)

        await model.selectProfile(3)
        model.editingProfileName = "Renamed"
        await model.renameSelectedProfile()
        await model.createProfile()

        let bodies = harness.requests("POST", path: "/uconfig.php").map(AccountHarness.body(of:))
        #expect(bodies == [
            "profile_set=3",
            "profile_action=rename&profile_name=Renamed&profile_set=1",
            "profile_action=create&profile_name=Default%20Profile&profile_set=1"
        ])
    }

    @Test func defaultProfileCannotBeDeletedOrMadeDefault() async throws {
        let harness = try await AccountHarness()
        let model = await loadedModel(harness)

        await model.deleteSelectedProfile()
        await model.setSelectedProfileAsDefault()

        #expect(harness.requests("POST", path: "/uconfig.php").isEmpty)
    }

    @Test func nonDefaultProfileCanBeDeletedAndMadeDefault() async throws {
        let harness = try await AccountHarness()
        let model = harness.make { EhSettingModel() }
        let profiles = [EhProfile(value: 1, name: "Default", isSelected: false), EhProfile(value: 3, name: "Other", isSelected: true)]
        model.apply(EhSetting(copying: .empty, profiles: profiles))
        harness.transport.on(.settingsPost, reply: AccountFixture.settings)

        await model.setSelectedProfileAsDefault()
        model.apply(EhSetting(copying: .empty, profiles: profiles))
        await model.deleteSelectedProfile()

        let bodies = harness.requests("POST", path: "/uconfig.php").map(AccountHarness.body(of:))
        #expect(bodies == ["profile_action=default&profile_set=3", "profile_action=delete&profile_set=3"])
    }

    @Test func leavingRestoresTheEhPandaProfile() async throws {
        let harness = try await AccountHarness()
        let model = await loadedModel(harness)
        harness.session.selectProfile(3)

        model.restoreEhPandaProfile()

        #expect(harness.cookie(CookieName.selectedProfile, GalleryHost.ehentai.url) == "2")
    }

    @Test func webViewFollowsHostAndDomainFronting() async throws {
        let harness = try await AccountHarness()
        harness.settings.galleryHost = .exhentai
        let model = harness.make { EhSettingModel() }
        model.presentWebView()
        #expect(model.destination == .webView(URL(string: "https://exhentai.org/uconfig.php")!))

        model.destination = nil
        harness.settings.bypassesSNIFiltering = true
        model.presentWebView()
        #expect(model.destination == nil)
    }
}

private extension EhSetting {
    init(copying base: EhSetting, profiles: [EhProfile]) {
        self.init(
            ehProfiles: profiles, isCapableOfCreatingNewProfile: base.isCapableOfCreatingNewProfile,
            capableLoadThroughHathSetting: base.capableLoadThroughHathSetting,
            capableImageResolution: base.capableImageResolution,
            capableSearchResultCount: base.capableSearchResultCount,
            capableThumbnailConfigRowCount: base.capableThumbnailConfigRowCount,
            capableThumbnailConfigSizes: base.capableThumbnailConfigSizes,
            loadThroughHathSetting: base.loadThroughHathSetting, browsingCountry: base.browsingCountry,
            literalBrowsingCountry: base.literalBrowsingCountry, imageResolution: base.imageResolution,
            imageSizeWidth: base.imageSizeWidth, imageSizeHeight: base.imageSizeHeight,
            galleryName: base.galleryName, archiverBehavior: base.archiverBehavior,
            displayMode: base.displayMode, showSearchRangeIndicator: base.showSearchRangeIndicator,
            enableGalleryThumbnailSelector: base.enableGalleryThumbnailSelector,
            disabledCategories: base.disabledCategories, favoriteCategories: base.favoriteCategories,
            favoritesSortOrder: base.favoritesSortOrder, ratingsColor: base.ratingsColor,
            tagFilteringThreshold: base.tagFilteringThreshold, tagWatchingThreshold: base.tagWatchingThreshold,
            showFilteredRemovalCount: base.showFilteredRemovalCount, excludedLanguages: base.excludedLanguages,
            excludedUploaders: base.excludedUploaders, searchResultCount: base.searchResultCount,
            thumbnailLoadTiming: base.thumbnailLoadTiming, thumbnailConfigSize: base.thumbnailConfigSize,
            thumbnailConfigRows: base.thumbnailConfigRows, coverScaleFactor: base.coverScaleFactor,
            viewportVirtualWidth: base.viewportVirtualWidth, commentsSortOrder: base.commentsSortOrder,
            commentVotesShowTiming: base.commentVotesShowTiming, tagsSortOrder: base.tagsSortOrder,
            galleryPageNumbering: base.galleryPageNumbering
        )
    }
}
