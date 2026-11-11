@testable import EhCore
import EhModels
import Foundation
import Testing

@MainActor @Suite struct SettingsStoreTests {
    @Test func emptyDefaultsLoadSettingDefaults() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        #expect(store.setting == Setting())
        #expect(storage.storedSettingKeys.isEmpty)
    }

    @Test func everyPropertyPersistsAndReloads() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.apply(.nonDefault)
        #expect(store.setting == .nonDefault)
        #expect(storage.storedSettingKeys == Set(SettingKey.allCases))
        #expect(SettingsStore(storage: storage).setting == .nonDefault)
    }

    @Test(arguments: SettingKey.allCases)
    func eachPropertyWritesOnlyItsOwnKey(key: SettingKey) throws {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        var expectedKeys: Set = [key]
        if [.translatesTags, .showsTagsSearchSuggestion, .showsImagesInTags].contains(key) {
            // These only stick while the tags extension is on (see the coupling rules).
            store.enablesTagsExtension = true
            expectedKeys.insert(.enablesTagsExtension)
        }
        let setValue = try #require(Self.setters[key])
        setValue(store, .nonDefault)
        #expect(storage.storedSettingKeys == expectedKeys)
        #expect(SettingsStore(storage: storage).setting == store.setting)
        #expect(store.setting != Setting())
    }

    /// Sets one property, through the store's own setter, to its value in the given setting.
    private static let setters: [SettingKey: @MainActor (SettingsStore, Setting) -> Void] = [
        .galleryHost: { $0.galleryHost = $1.galleryHost },
        .showsNewDawnGreeting: { $0.showsNewDawnGreeting = $1.showsNewDawnGreeting },
        .enablesTagsExtension: { $0.enablesTagsExtension = $1.enablesTagsExtension },
        .translatesTags: { $0.translatesTags = $1.translatesTags },
        .showsTagsSearchSuggestion: { $0.showsTagsSearchSuggestion = $1.showsTagsSearchSuggestion },
        .showsImagesInTags: { $0.showsImagesInTags = $1.showsImagesInTags },
        .redirectsLinksToSelectedHost: { $0.redirectsLinksToSelectedHost = $1.redirectsLinksToSelectedHost },
        .detectsLinksFromClipboard: { $0.detectsLinksFromClipboard = $1.detectsLinksFromClipboard },
        .backgroundBlurRadius: { $0.backgroundBlurRadius = $1.backgroundBlurRadius },
        .autoLockPolicy: { $0.autoLockPolicy = $1.autoLockPolicy },
        .listDisplayMode: { $0.listDisplayMode = $1.listDisplayMode },
        .preferredColorScheme: { $0.preferredColorScheme = $1.preferredColorScheme },
        .accentColor: { $0.accentColor = $1.accentColor },
        .appIconType: { $0.appIconType = $1.appIconType },
        .showsTagsInList: { $0.showsTagsInList = $1.showsTagsInList },
        .listTagsNumberMaximum: { $0.listTagsNumberMaximum = $1.listTagsNumberMaximum },
        .displaysJapaneseTitle: { $0.displaysJapaneseTitle = $1.displaysJapaneseTitle },
        .readingDirection: { $0.readingDirection = $1.readingDirection },
        .prefetchLimit: { $0.prefetchLimit = $1.prefetchLimit },
        .enablesLandscape: { $0.enablesLandscape = $1.enablesLandscape },
        .enablesDualPageMode: { $0.enablesDualPageMode = $1.enablesDualPageMode },
        .exceptCover: { $0.exceptCover = $1.exceptCover },
        .contentDividerHeight: { $0.contentDividerHeight = $1.contentDividerHeight },
        .maximumScaleFactor: { $0.maximumScaleFactor = $1.maximumScaleFactor },
        // 2.5 stays under the default maximum, so no rule touches the maximum's key.
        .doubleTapScaleFactor: { store, _ in store.doubleTapScaleFactor = 2.5 },
        .bypassesSNIFiltering: { $0.bypassesSNIFiltering = $1.bypassesSNIFiltering }
    ]

    @Test func everyKeyHasASetter() {
        #expect(Set(Self.setters.keys) == Set(SettingKey.allCases))
    }

    @Test func assigningTheSameValueWritesNothing() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.apply(Setting())
        store.prefetchLimit = 10
        #expect(storage.storedSettingKeys.isEmpty)
    }

    @Test func keySchemeAndPropertyListRepresentations() {
        let storage = PreferenceStorage.ephemeral()
        SettingsStore(storage: storage).apply(.nonDefault)
        let defaults = storage.defaults
        #expect(defaults.string(forKey: "galleryHost") == "ExHentai")
        #expect(defaults.object(forKey: "settings.autoLockPolicy") as? Int == 300)
        #expect(defaults.object(forKey: "settings.readingDirection") as? Int == 1)
        #expect(defaults.object(forKey: "settings.showsTagsInList") as? Bool == true)
        #expect(defaults.object(forKey: "settings.backgroundBlurRadius") as? Double == 30)
        #expect(defaults.object(forKey: "settings.accentColor") as? [Double] == [0.1, 0.25, 0.3])
    }

    @Test func invalidStoredValuesFallBackToDefaults() {
        let storage = PreferenceStorage.ephemeral()
        storage.defaults.set("Nope", forKey: "galleryHost")
        storage.defaults.set("ten", forKey: "settings.prefetchLimit")
        storage.defaults.set(42, forKey: "settings.readingDirection")
        storage.defaults.set([0.5], forKey: "settings.accentColor")
        storage.defaults.set(7, forKey: "settings.listTagsNumberMaximum")
        let store = SettingsStore(storage: storage)
        #expect(store.galleryHost == .ehentai)
        #expect(store.prefetchLimit == 10)
        #expect(store.readingDirection == .vertical)
        #expect(store.accentColor == .systemBlue)
        #expect(store.listTagsNumberMaximum == 7)
    }

    // MARK: Gallery host

    @Test func hostProviderReadsWhatTheStoreWrote() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        let provider = store.galleryHostProvider
        #expect(provider.current == .ehentai)
        store.galleryHost = .exhentai
        #expect(provider.current == .exhentai)
        #expect(GalleryHostProvider(defaults: storage.defaults).currentHost() == .exhentai)
        store.galleryHost = .ehentai
        #expect(provider.current == .ehentai)
    }

    @Test func readsTheHostTheLegacyAppMirrored() {
        let storage = PreferenceStorage.ephemeral()
        storage.defaults.set("ExHentai", forKey: "galleryHost")
        #expect(SettingsStore(storage: storage).galleryHost == .exhentai)
    }

    @Test func providerReadsFromAnotherThread() async {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.galleryHost = .exhentai
        let provider = store.galleryHostProvider
        let host = await Task.detached { provider.current }.value
        #expect(host == .exhentai)
    }

    // MARK: Snapshot and apply

    @Test func applyAndSnapshotRoundTrip() {
        let store = SettingsStore(storage: .ephemeral())
        store.apply(.nonDefault)
        #expect(store.setting == .nonDefault)
        store.apply(Setting())
        #expect(store.setting == Setting())
    }

    // MARK: Device default list display mode

    @Test func defaultListDisplayModeAppliesOnceOnAFreshInstall() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.registerDefaultListDisplayMode(.thumbnail)
        #expect(store.listDisplayMode == .thumbnail)
        store.registerDefaultListDisplayMode(.detail)
        #expect(store.listDisplayMode == .thumbnail)
        #expect(SettingsStore(storage: storage).listDisplayMode == .thumbnail)
    }

    @Test func defaultListDisplayModeIsStoredEvenWhenItEqualsTheBuiltInDefault() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.registerDefaultListDisplayMode(.detail)
        store.registerDefaultListDisplayMode(.thumbnail)
        #expect(store.listDisplayMode == .detail)
    }

    @Test func defaultListDisplayModeDoesNotOverrideAStoredValue() {
        let storage = PreferenceStorage.ephemeral()
        storage.defaults.set(ListDisplayMode.detail.rawValue, forKey: "settings.listDisplayMode")
        let store = SettingsStore(storage: storage)
        store.registerDefaultListDisplayMode(.thumbnail)
        #expect(store.listDisplayMode == .detail)
    }

    @Test func defaultListDisplayModeDoesNotOverrideAUserChoice() {
        let store = SettingsStore(storage: .ephemeral())
        store.listDisplayMode = .thumbnail
        store.registerDefaultListDisplayMode(.detail)
        #expect(store.listDisplayMode == .thumbnail)
    }

    // MARK: Observation

    @Test func observationFiresForTheChangedPropertyOnly() {
        let store = SettingsStore(storage: .ephemeral())
        #expect(!changeIsObserved(reading: { _ = store.showsTagsInList }, after: { store.translatesTags = true }))
        #expect(!changeIsObserved(reading: { _ = store.showsTagsInList }, after: { store.prefetchLimit = 18 }))
        #expect(changeIsObserved(reading: { _ = store.showsTagsInList }, after: { store.showsTagsInList = true }))
        #expect(changeIsObserved(reading: { _ = store.accentColor }, after: {
            store.accentColor = RGBColor(red: 1, green: 0, blue: 0)
        }))
    }

    @Test func aRuleThatChangesNothingDoesNotNotify() {
        let store = SettingsStore(storage: .ephemeral())
        // The extension is already off, so turning it "off" again leaves dependents untouched.
        #expect(!changeIsObserved(reading: { _ = store.translatesTags }, after: {
            store.enablesTagsExtension = false
        }))
    }
}
