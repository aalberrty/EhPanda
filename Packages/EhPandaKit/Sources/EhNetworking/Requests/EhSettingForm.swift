import EhModels
import Foundation

/// The `uconfig.php` form fields for an `EhSetting` (legacy `SubmitEhSettingChangesRequest`).
///
/// Unchecked checkboxes are omitted, as a browser would. Several booleans are inverted
/// because the site's radio buttons ask the opposite question.
enum EhSettingForm {
    static func fields(for setting: EhSetting) -> [(String, String)] {
        var fields = scalarFields(setting)

        if setting.enableGalleryThumbnailSelector {
            fields.append(("xn_0", "on"))
        }
        // `.large` is deprecated by the site and sends nothing.
        switch setting.thumbnailConfigSize {
        case .auto: fields.append(("ts", "0"))
        case .normal: fields.append(("ts", "1"))
        case .small: fields.append(("ts", "2"))
        case .large: break
        }

        for (index, name) in EhSetting.categoryNames.enumerated()
        where setting.disabledCategories.indices.contains(index) {
            fields.append(("ct_\(name)", setting.disabledCategories[index] ? "1" : "0"))
        }
        for index in 0...9 where setting.favoriteCategories.indices.contains(index) {
            fields.append(("favorite_\(index)", setting.favoriteCategories[index]))
        }
        for (index, isExcluded) in setting.excludedLanguages.enumerated()
        where isExcluded && EhSetting.languageValues.indices.contains(index) {
            fields.append(("xl_\(EhSetting.languageValues[index])", "on"))
        }

        fields += optionalFields(setting)
        return fields
    }

    private static func scalarFields(_ setting: EhSetting) -> [(String, String)] {
        [
            ("uh", String(setting.loadThroughHathSetting.rawValue)),
            ("co", setting.browsingCountry.rawValue),
            ("xr", String(setting.imageResolution.rawValue)),
            ("rx", String(Int(setting.imageSizeWidth))),
            ("ry", String(Int(setting.imageSizeHeight))),
            ("tl", String(setting.galleryName.rawValue)),
            ("ar", String(setting.archiverBehavior.rawValue)),
            ("dm", String(setting.displayMode.rawValue)),
            ("pp", setting.showSearchRangeIndicator ? "0" : "1"),
            ("fs", String(setting.favoritesSortOrder.rawValue)),
            ("ru", setting.ratingsColor),
            ("ft", String(Int(setting.tagFilteringThreshold))),
            ("wt", String(Int(setting.tagWatchingThreshold))),
            ("tf", setting.showFilteredRemovalCount ? "0" : "1"),
            ("xu", setting.excludedUploaders),
            ("rc", String(setting.searchResultCount.rawValue)),
            ("lt", String(setting.thumbnailLoadTiming.rawValue)),
            ("tr", String(setting.thumbnailConfigRows.rawValue)),
            ("tp", String(Int(setting.coverScaleFactor))),
            ("vp", String(Int(setting.viewportVirtualWidth))),
            ("cs", String(setting.commentsSortOrder.rawValue)),
            ("sc", String(setting.commentVotesShowTiming.rawValue)),
            ("tb", String(setting.tagsSortOrder.rawValue)),
            ("pn", String(setting.galleryPageNumbering.rawValue)),
            ("apply", "Apply")
        ]
    }

    /// Settings that only some accounts see; absent ones are not sent.
    private static func optionalFields(_ setting: EhSetting) -> [(String, String)] {
        var fields = [(String, String)]()
        if let useOriginalImages = setting.useOriginalImages {
            fields.append(("oi", useOriginalImages ? "1" : "0"))
        }
        if let useMultiplePageViewer = setting.useMultiplePageViewer {
            fields.append(("qb", useMultiplePageViewer ? "1" : "0"))
        }
        if let style = setting.multiplePageViewerStyle {
            fields.append(("ms", String(style.rawValue)))
        }
        if let showThumbnailPane = setting.multiplePageViewerShowThumbnailPane {
            fields.append(("mt", showThumbnailPane ? "0" : "1"))
        }
        return fields
    }
}
