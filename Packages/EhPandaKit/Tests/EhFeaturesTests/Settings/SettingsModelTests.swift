import Dependencies
import EhCore
import EhDatabase
import EhFeatures
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct AppIconModelTests {
    @Test func selectingAnIconSetsTheAlternateIconAndRecordsWhatTheSystemReports() async {
        let iconName = SettingsTestLock<String?>(nil)
        let settings = SettingsStore.ephemeral()
        let model = withDependencies {
            $0.settings = settings
            $0.applicationClient.setAlternateIconName = { name in
                iconName.withLock { $0 = name }
                return true
            }
            $0.applicationClient.alternateIconName = { iconName.withLock { $0 } }
        } operation: { AppIconModel() }

        await model.select(.ukiyoe)

        #expect(iconName.withLock { $0 } == "AppIcon_Ukiyoe")
        #expect(settings.appIconType == .ukiyoe)

        await model.select(.default)

        #expect(iconName.withLock { $0 } == "AppIcon_Default")
        #expect(settings.appIconType == .default)
    }

    @Test func aRefusedChangeKeepsTheIconTheSystemShows() async {
        let settings = SettingsStore.ephemeral()
        let model = withDependencies {
            $0.settings = settings
            $0.applicationClient.setAlternateIconName = { _ in false }
            $0.applicationClient.alternateIconName = { "AppIcon_Developer" }
        } operation: { AppIconModel() }

        await model.select(.notMyPresidnet)

        #expect(settings.appIconType == .developer)
    }

    @Test func syncMapsThePrimaryAndUnknownIconsToDefault() {
        let settings = SettingsStore.ephemeral()
        let reported = SettingsTestLock<String?>("AppIcon_StandWithUkraine2022")
        let model = withDependencies {
            $0.settings = settings
            $0.applicationClient.alternateIconName = { reported.withLock { $0 } }
        } operation: { AppIconModel() }

        model.syncWithSystem()
        #expect(settings.appIconType == .standWithUkraine2022)

        reported.withLock { $0 = nil }
        model.syncWithSystem()
        #expect(settings.appIconType == .default)

        settings.appIconType = .ukiyoe
        reported.withLock { $0 = "SomethingElse" }
        model.syncWithSystem()
        #expect(settings.appIconType == .default)
    }
}

@Suite struct GeneralSettingsModelTests {
    @Test func appearingChecksThePasscodeAndMeasuresTheCache() async {
        let model = withDependencies {
            $0.biometricsClient.isAvailable = { false }
            $0.imageCacheClient.diskCacheSize = { 4096 }
        } operation: { GeneralSettingsModel() }
        #expect(model.isPasscodeSet)
        #expect(model.imageCacheSize == nil)

        await model.onAppear()

        #expect(!model.isPasscodeSet)
        #expect(model.imageCacheSize == 4096)
    }

    @Test func aFailedMeasurementKeepsTheSizeUnknown() async {
        struct Failure: Error {}
        let model = withDependencies {
            $0.imageCacheClient.diskCacheSize = { throw Failure() }
        } operation: { GeneralSettingsModel() }

        await model.refreshImageCacheSize()

        #expect(model.imageCacheSize == nil)
    }

    @Test func clearingTheCacheRemovesStoredImageURLsAndRemeasures() async throws {
        let database = try await TestDatabase.inMemory()
        let url = URL(string: "https://ehgt.org/image.webp")
        try await database.upsertPages([
            GalleryPage(gid: "1", index: 1, imageURL: url, previewURL: url),
            GalleryPage(gid: "2", index: 3, pageURL: url, originalImageURL: url)
        ])
        let size = SettingsTestLock(1_000_000)
        let model = withDependencies {
            $0.database = database
            $0.imageCacheClient.diskCacheSize = { size.withLock { $0 } }
            $0.imageCacheClient.clearDiskCache = { size.withLock { $0 = 0 } }
        } operation: { GeneralSettingsModel() }
        await model.refreshImageCacheSize()
        #expect(model.imageCacheSize == 1_000_000)

        await model.clearImageCache()

        #expect(model.imageCacheSize == 0)
        #expect(!model.isClearingImageCache)
        #expect(try await database.pages(gid: "1").isEmpty)
        #expect(try await database.pages(gid: "2").isEmpty)
    }

    @Test func languageOpensTheSettingsApp() async {
        let opened = SettingsTestLock(false)
        let model = withDependencies {
            $0.applicationClient.openSettings = { opened.withLock { $0 = true } }
        } operation: { GeneralSettingsModel() }

        await model.openSystemSettings()

        #expect(opened.withLock { $0 })
    }
}

@Suite struct LaboratorySettingsModelTests {
    @Test func togglingSNIBypassStoresTheSettingAndSwitchesTheTransport() {
        let settings = SettingsStore.ephemeral()
        let enabled = SettingsTestLock(false)
        let model = withDependencies {
            $0.settings = settings
            $0.domainFronting = DomainFrontingClient(
                isEnabled: { enabled.withLock { $0 } },
                setEnabled: { value in enabled.withLock { $0 = value } }
            )
        } operation: { LaboratorySettingsModel() }

        model.setBypassesSNIFiltering(true)
        #expect(settings.bypassesSNIFiltering)
        #expect(enabled.withLock { $0 })

        model.setBypassesSNIFiltering(false)
        #expect(!settings.bypassesSNIFiltering)
        #expect(!enabled.withLock { $0 })
    }
}

@Suite struct ReadingSettingsModelTests {
    private func makeModel(isPad: Bool, settings: SettingsStore, locks: SettingsTestLock<[OrientationLock]>) -> ReadingSettingsModel {
        withDependencies {
            $0.settings = settings
            $0.applicationClient.isPad = { isPad }
            $0.applicationClient.setOrientationLock = { lock in locks.withLock { $0.append(lock) } }
        } operation: { ReadingSettingsModel() }
    }

    @Test func turningLandscapeOffOnIPhoneRestoresPortrait() {
        let settings = SettingsStore.ephemeral()
        let locks = SettingsTestLock<[OrientationLock]>([])
        let model = makeModel(isPad: false, settings: settings, locks: locks)

        model.setEnablesLandscape(true)
        #expect(settings.enablesLandscape)
        #expect(locks.withLock { $0 }.isEmpty)

        model.setEnablesLandscape(false)
        #expect(!settings.enablesLandscape)
        #expect(locks.withLock { $0 } == [.portrait])
    }

    @Test func iPadKeepsItsOrientation() {
        let settings = SettingsStore.ephemeral()
        let locks = SettingsTestLock<[OrientationLock]>([])
        let model = makeModel(isPad: true, settings: settings, locks: locks)

        model.setEnablesLandscape(false)

        #expect(locks.withLock { $0 }.isEmpty)
    }
}
