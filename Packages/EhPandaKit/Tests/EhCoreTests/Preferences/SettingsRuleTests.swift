@testable import EhCore
import EhModels
import Foundation
import Testing

@MainActor @Suite struct SettingsRuleTests {
    // MARK: Tags extension

    @Test func turningTheTagsExtensionOffTurnsOffItsFeatures() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.enablesTagsExtension = true
        store.translatesTags = true
        store.showsTagsSearchSuggestion = true
        store.showsImagesInTags = true

        store.enablesTagsExtension = false
        #expect(!store.translatesTags && !store.showsTagsSearchSuggestion && !store.showsImagesInTags)
        let reloaded = SettingsStore(storage: storage)
        #expect(!reloaded.translatesTags && !reloaded.showsTagsSearchSuggestion && !reloaded.showsImagesInTags)
    }

    @Test func turningTheTagsExtensionOnLeavesItsFeaturesAlone() {
        let store = SettingsStore(storage: .ephemeral())
        store.enablesTagsExtension = true
        #expect(!store.translatesTags && !store.showsTagsSearchSuggestion && !store.showsImagesInTags)
        store.translatesTags = true
        store.enablesTagsExtension = true
        #expect(store.translatesTags)
    }

    // MARK: Auto-lock and blur

    @Test func choosingAutoLockWithNoBlurSetsTheBlurTo10() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.backgroundBlurRadius = 0
        store.autoLockPolicy = .min1
        #expect(store.backgroundBlurRadius == 10)
        #expect(store.autoLockPolicy == .min1)
        #expect(SettingsStore(storage: storage).backgroundBlurRadius == 10)
    }

    @Test func choosingAutoLockKeepsANonZeroBlur() {
        let store = SettingsStore(storage: .ephemeral())
        store.backgroundBlurRadius = 40
        store.autoLockPolicy = .instantly
        #expect(store.backgroundBlurRadius == 40)
    }

    @Test func choosingNeverKeepsAZeroBlur() {
        let store = SettingsStore(storage: .ephemeral())
        store.backgroundBlurRadius = 0
        store.autoLockPolicy = .never
        #expect(store.backgroundBlurRadius == 0)
    }

    @Test func zeroBlurTurnsAutoLockOff() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.autoLockPolicy = .min30
        store.backgroundBlurRadius = 0
        #expect(store.autoLockPolicy == .never)
        #expect(store.backgroundBlurRadius == 0)
        #expect(SettingsStore(storage: storage).autoLockPolicy == .never)
    }

    @Test func nonZeroBlurKeepsAutoLock() {
        let store = SettingsStore(storage: .ephemeral())
        store.autoLockPolicy = .sec15
        store.backgroundBlurRadius = 20
        #expect(store.autoLockPolicy == .sec15)
    }

    // MARK: Zoom factors

    @Test func loweringTheMaximumBelowDoubleTapLowersDoubleTap() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.maximumScaleFactor = 1.5
        #expect(store.doubleTapScaleFactor == 1.5)
        #expect(SettingsStore(storage: storage).doubleTapScaleFactor == 1.5)
    }

    @Test func raisingTheMaximumKeepsDoubleTap() {
        let store = SettingsStore(storage: .ephemeral())
        store.maximumScaleFactor = 8
        #expect(store.doubleTapScaleFactor == 2)
    }

    @Test func raisingDoubleTapAboveTheMaximumRaisesTheMaximum() {
        let storage = PreferenceStorage.ephemeral()
        let store = SettingsStore(storage: storage)
        store.doubleTapScaleFactor = 5
        #expect(store.maximumScaleFactor == 5)
        #expect(SettingsStore(storage: storage).maximumScaleFactor == 5)
    }

    @Test func loweringDoubleTapKeepsTheMaximum() {
        let store = SettingsStore(storage: .ephemeral())
        store.doubleTapScaleFactor = 1.5
        #expect(store.maximumScaleFactor == 3)
    }

    // MARK: Whole values

    @Test func applyMakesAnInconsistentSettingConsistent() {
        var setting = Setting()
        setting.translatesTags = true
        setting.showsImagesInTags = true
        setting.autoLockPolicy = .min1
        setting.backgroundBlurRadius = 0
        setting.maximumScaleFactor = 2
        setting.doubleTapScaleFactor = 4

        let store = SettingsStore(storage: .ephemeral())
        store.apply(setting)
        #expect(!store.translatesTags && !store.showsImagesInTags)
        #expect(store.autoLockPolicy == .min1 && store.backgroundBlurRadius == 10)
        #expect(store.maximumScaleFactor == 2 && store.doubleTapScaleFactor == 2)
        #expect(store.setting == setting.enforcingRules())
    }

    @Test func loadingInconsistentStoredValuesMakesThemConsistent() {
        let storage = PreferenceStorage.ephemeral()
        storage.defaults.set(true, forKey: "settings.showsTagsSearchSuggestion")
        storage.defaults.set(60, forKey: "settings.autoLockPolicy")
        storage.defaults.set(0.0, forKey: "settings.backgroundBlurRadius")
        storage.defaults.set(4.0, forKey: "settings.doubleTapScaleFactor")
        let store = SettingsStore(storage: storage)
        #expect(!store.showsTagsSearchSuggestion)
        #expect(store.autoLockPolicy == .min1 && store.backgroundBlurRadius == 10)
        #expect(store.maximumScaleFactor == 3 && store.doubleTapScaleFactor == 3)
    }

    @Test func enforcingRulesKeepsAConsistentSetting() {
        #expect(Setting.nonDefault.enforcingRules() == .nonDefault)
        #expect(Setting().enforcingRules() == Setting())
    }
}
