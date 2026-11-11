@testable import EhCore
import EhModels
import Foundation
import Observation
import Synchronization

/// Whether reading `read` registers an observation that `change` then triggers.
@MainActor
func changeIsObserved(reading read: () -> Void, after change: () -> Void) -> Bool {
    let fired = Flag()
    withObservationTracking(read) { fired.set() }
    change()
    return fired.value
}

private final class Flag: Sendable {
    private let state = Mutex(false)
    func set() { state.withLock { $0 = true } }
    var value: Bool { state.withLock { $0 } }
}

extension PreferenceStorage {
    /// The setting keys that have a stored value.
    var storedSettingKeys: Set<SettingKey> {
        Set(SettingKey.allCases.filter(contains))
    }
}

extension Setting {
    /// Every field differs from `Setting()` and every coupling rule is satisfied.
    static let nonDefault: Setting = {
        var setting = Setting()
        setting.galleryHost = .exhentai
        setting.showsNewDawnGreeting = true
        setting.enablesTagsExtension = true
        setting.translatesTags = true
        setting.showsTagsSearchSuggestion = true
        setting.showsImagesInTags = true
        setting.redirectsLinksToSelectedHost = true
        setting.detectsLinksFromClipboard = true
        setting.backgroundBlurRadius = 30
        setting.autoLockPolicy = .min5
        setting.listDisplayMode = .thumbnail
        setting.preferredColorScheme = .dark
        setting.accentColor = RGBColor(red: 0.1, green: 0.25, blue: 0.3)
        setting.appIconType = .ukiyoe
        setting.showsTagsInList = true
        setting.listTagsNumberMaximum = 15
        setting.displaysJapaneseTitle = false
        setting.readingDirection = .rightToLeft
        setting.prefetchLimit = 14
        setting.enablesLandscape = true
        setting.enablesDualPageMode = true
        setting.exceptCover = true
        setting.contentDividerHeight = 10
        setting.maximumScaleFactor = 6
        setting.doubleTapScaleFactor = 4.5
        setting.bypassesSNIFiltering = true
        return setting
    }()
}

func json(_ string: String) -> Data {
    Data(string.utf8)
}
