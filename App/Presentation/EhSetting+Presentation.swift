import EhModels

extension EhSetting.LoadThroughHathSetting {
    var localizedName: String {
        switch self {
        case .anyClient: L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Value.anyClient
        case .defaultPortOnly: L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Value.defaultPortOnly
        case .modernNo: L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Value.modernNo
        case .legacyNo: L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Value.legacyNo
        }
    }

    var localizedDescription: String {
        switch self {
        case .anyClient: L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Description.anyClient
        case .defaultPortOnly: L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Description.defaultPortOnly
        case .modernNo: L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Description.modernNo
        case .legacyNo: L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Description.legacyNo
        }
    }
}

extension EhSetting.ImageResolution {
    var localizedName: String {
        switch self {
        case .auto: L10n.Localizable.Enum.EhSetting.ImageResolution.Value.auto
        case .x780: "780x"
        case .x980: "980x"
        case .x1280: "1280x"
        case .x1600: "1600x"
        case .x2400: "2400x"
        }
    }
}

extension EhSetting.GalleryName {
    var localizedName: String {
        switch self {
        case .default: L10n.Localizable.Enum.EhSetting.GalleryName.Value.default
        case .japanese: L10n.Localizable.Enum.EhSetting.GalleryName.Value.japanese
        }
    }
}

extension EhSetting.ArchiverBehavior {
    var localizedName: String {
        switch self {
        case .manualSelectManualStart: L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.manualSelectManualStart
        case .manualSelectAutoStart: L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.manualSelectAutoStart
        case .autoSelectOriginalManualStart: L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.autoSelectOriginalManualStart
        case .autoSelectOriginalAutoStart: L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.autoSelectOriginalAutoStart
        case .autoSelectResampleManualStart: L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.autoSelectResampleManualStart
        case .autoSelectResampleAutoStart: L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.autoSelectResampleAutoStart
        }
    }
}

extension EhSetting.DisplayMode {
    var localizedName: String {
        switch self {
        case .compact: L10n.Localizable.Enum.EhSetting.DisplayMode.Value.compact
        case .thumbnail: L10n.Localizable.Enum.EhSetting.DisplayMode.Value.thumbnail
        case .extended: L10n.Localizable.Enum.EhSetting.DisplayMode.Value.extended
        case .minimal: L10n.Localizable.Enum.EhSetting.DisplayMode.Value.minimal
        case .minimalPlus: L10n.Localizable.Enum.EhSetting.DisplayMode.Value.minimalPlus
        }
    }
}

extension EhSetting.FavoritesSortOrder {
    var localizedName: String {
        switch self {
        case .lastUpdateTime: L10n.Localizable.Enum.EhSetting.FavoritesSortOrder.Value.lastUpdateTime
        case .favoritedTime: L10n.Localizable.Enum.EhSetting.FavoritesSortOrder.Value.favoritedTime
        }
    }
}

extension EhSetting.ExcludedLanguagesCategory {
    var localizedName: String {
        switch self {
        case .original: L10n.Localizable.Enum.EhSetting.ExcludedLanguagesCategory.Value.original
        case .translated: L10n.Localizable.Enum.EhSetting.ExcludedLanguagesCategory.Value.translated
        case .rewrite: L10n.Localizable.Enum.EhSetting.ExcludedLanguagesCategory.Value.rewrite
        }
    }
}

extension EhSetting.SearchResultCount {
    var localizedName: String {
        switch self {
        case .twentyFive: "25"
        case .fifty: "50"
        case .oneHundred: "100"
        case .twoHundred: "200"
        }
    }
}

extension EhSetting.ThumbnailLoadTiming {
    var localizedName: String {
        switch self {
        case .onMouseOver: L10n.Localizable.Enum.EhSetting.ThumbnailLoadTiming.Value.onMouseOver
        case .onPageLoad: L10n.Localizable.Enum.EhSetting.ThumbnailLoadTiming.Value.onPageLoad
        }
    }

    var localizedDescription: String {
        switch self {
        case .onMouseOver: L10n.Localizable.Enum.EhSetting.ThumbnailLoadTiming.Description.onMouseOver
        case .onPageLoad: L10n.Localizable.Enum.EhSetting.ThumbnailLoadTiming.Description.onPageLoad
        }
    }
}

extension EhSetting.ThumbnailSize {
    var localizedName: String {
        switch self {
        case .normal: L10n.Localizable.Enum.EhSetting.ThumbnailSize.Value.normal
        case .large: L10n.Localizable.Enum.EhSetting.ThumbnailSize.Value.large
        case .small: L10n.Localizable.Enum.EhSetting.ThumbnailSize.Value.small
        case .auto: L10n.Localizable.Enum.EhSetting.ThumbnailSize.Value.auto
        }
    }
}

extension EhSetting.ThumbnailRowCount {
    var localizedName: String {
        switch self {
        case .four: "4"
        case .ten: "8"
        case .twenty: "20"
        case .forty: "40"
        }
    }
}

extension EhSetting.CommentsSortOrder {
    var localizedName: String {
        switch self {
        case .oldest: L10n.Localizable.Enum.EhSetting.CommentsSortOrder.Value.oldest
        case .recent: L10n.Localizable.Enum.EhSetting.CommentsSortOrder.Value.recent
        case .highestScore: L10n.Localizable.Enum.EhSetting.CommentsSortOrder.Value.highestScore
        }
    }
}

extension EhSetting.CommentVotesShowTiming {
    var localizedName: String {
        switch self {
        case .onHoverOrClick: L10n.Localizable.Enum.EhSetting.CommentsVotesShowTiming.Value.onHoverOrClick
        case .always: L10n.Localizable.Enum.EhSetting.CommentsVotesShowTiming.Value.always
        }
    }
}

extension EhSetting.TagsSortOrder {
    var localizedName: String {
        switch self {
        case .alphabetical: L10n.Localizable.Enum.EhSetting.TagsSortOrder.Value.alphabetical
        case .tagPower: L10n.Localizable.Enum.EhSetting.TagsSortOrder.Value.tagPower
        }
    }
}

extension EhSetting.MultiplePageViewerStyle {
    var localizedName: String {
        switch self {
        case .alignLeftScaleIfOverWidth: L10n.Localizable.Enum.EhSetting.MultiplePageViewerStyle.Value.alignLeftScaleIfOverWidth
        case .alignCenterScaleIfOverWidth: L10n.Localizable.Enum.EhSetting.MultiplePageViewerStyle.Value.alignCenterScaleIfOverWidth
        case .alignCenterAlwaysScale: L10n.Localizable.Enum.EhSetting.MultiplePageViewerStyle.Value.alignCenterAlwaysScale
        }
    }
}

extension EhSetting.GalleryPageNumbering {
    var localizedName: String {
        switch self {
        case .none: L10n.Localizable.Enum.EhSetting.GalleryPageNumbering.Value.none
        case .pageNumberOnly: L10n.Localizable.Enum.EhSetting.GalleryPageNumbering.Value.pageNumberOnly
        case .pageNumberAndName: L10n.Localizable.Enum.EhSetting.GalleryPageNumbering.Value.pageNumberAndName
        }
    }
}


extension EhSetting {
    /// The detected country's localized name, when it matches a known country.
    var localizedLiteralBrowsingCountry: String? {
        literalBrowsingCountryValue?.localizedName
    }
}
