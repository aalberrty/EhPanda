import EhModels

extension SettingsStore {
    /// Every setting as one value. Reading it observes every property, so views should read
    /// the individual properties instead.
    public var setting: Setting {
        var setting = Setting()
        setting.galleryHost = galleryHost
        setting.showsNewDawnGreeting = showsNewDawnGreeting
        setting.enablesTagsExtension = enablesTagsExtension
        setting.translatesTags = translatesTags
        setting.showsTagsSearchSuggestion = showsTagsSearchSuggestion
        setting.showsImagesInTags = showsImagesInTags
        setting.redirectsLinksToSelectedHost = redirectsLinksToSelectedHost
        setting.detectsLinksFromClipboard = detectsLinksFromClipboard
        setting.backgroundBlurRadius = backgroundBlurRadius
        setting.autoLockPolicy = autoLockPolicy
        setting.listDisplayMode = listDisplayMode
        setting.preferredColorScheme = preferredColorScheme
        setting.accentColor = accentColor
        setting.appIconType = appIconType
        setting.showsTagsInList = showsTagsInList
        setting.listTagsNumberMaximum = listTagsNumberMaximum
        setting.displaysJapaneseTitle = displaysJapaneseTitle
        setting.readingDirection = readingDirection
        setting.prefetchLimit = prefetchLimit
        setting.enablesLandscape = enablesLandscape
        setting.enablesDualPageMode = enablesDualPageMode
        setting.exceptCover = exceptCover
        setting.contentDividerHeight = contentDividerHeight
        setting.maximumScaleFactor = maximumScaleFactor
        setting.doubleTapScaleFactor = doubleTapScaleFactor
        setting.bypassesSNIFiltering = bypassesSNIFiltering
        return setting
    }

    /// Replaces every setting with `setting`, after making it satisfy the coupling rules
    /// (see `Setting.enforcingRules()`). Only the keys whose value changes are written.
    public func apply(_ setting: Setting) {
        // Assigning a value that already satisfies every rule never triggers a rule that
        // changes a field assigned earlier, so plain assignment in field order lands exactly on
        // `setting`.
        let setting = setting.enforcingRules()
        galleryHost = setting.galleryHost
        showsNewDawnGreeting = setting.showsNewDawnGreeting
        enablesTagsExtension = setting.enablesTagsExtension
        translatesTags = setting.translatesTags
        showsTagsSearchSuggestion = setting.showsTagsSearchSuggestion
        showsImagesInTags = setting.showsImagesInTags
        redirectsLinksToSelectedHost = setting.redirectsLinksToSelectedHost
        detectsLinksFromClipboard = setting.detectsLinksFromClipboard
        backgroundBlurRadius = setting.backgroundBlurRadius
        autoLockPolicy = setting.autoLockPolicy
        listDisplayMode = setting.listDisplayMode
        preferredColorScheme = setting.preferredColorScheme
        accentColor = setting.accentColor
        appIconType = setting.appIconType
        showsTagsInList = setting.showsTagsInList
        listTagsNumberMaximum = setting.listTagsNumberMaximum
        displaysJapaneseTitle = setting.displaysJapaneseTitle
        readingDirection = setting.readingDirection
        prefetchLimit = setting.prefetchLimit
        enablesLandscape = setting.enablesLandscape
        enablesDualPageMode = setting.enablesDualPageMode
        exceptCover = setting.exceptCover
        contentDividerHeight = setting.contentDividerHeight
        maximumScaleFactor = setting.maximumScaleFactor
        doubleTapScaleFactor = setting.doubleTapScaleFactor
        bypassesSNIFiltering = setting.bypassesSNIFiltering
    }

    /// Sets the device-dependent default list display mode (legacy: `.thumbnail` on iPad-width
    /// screens). Call it at launch, before the legacy import. It only takes effect when no
    /// display mode has ever been stored, and it stores `mode`, so it applies once per install
    /// and never overrides a user's or an imported choice.
    public func registerDefaultListDisplayMode(_ mode: ListDisplayMode) {
        guard !storage.contains(.listDisplayMode) else { return }
        listDisplayMode = mode
        storeListDisplayMode()
    }

    /// Stores the display mode even when it equals the built-in default, marking it decided.
    func storeListDisplayMode() {
        storage.set(listDisplayMode, for: .listDisplayMode)
    }

    /// Whether `key` has a value in `UserDefaults` (as opposed to a fallback default).
    func hasStoredValue(for key: SettingKey) -> Bool {
        storage.contains(key)
    }
}
