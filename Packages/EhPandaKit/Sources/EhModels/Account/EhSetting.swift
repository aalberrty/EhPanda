import Foundation

/// The user's settings on the site (`uconfig.php`), as parsed from and submitted to it.
///
/// The `capable…` members describe what the user's account level allows; the rest are
/// the current values.
public struct EhSetting: Sendable, Equatable {
    public let ehProfiles: [EhProfile]
    public let isCapableOfCreatingNewProfile: Bool
    public let capableLoadThroughHathSetting: LoadThroughHathSetting
    public let capableImageResolution: ImageResolution
    public let capableSearchResultCount: SearchResultCount
    public let capableThumbnailConfigRowCount: ThumbnailRowCount
    public let capableThumbnailConfigSizes: [ThumbnailSize]

    public var loadThroughHathSetting: LoadThroughHathSetting
    public var browsingCountry: BrowsingCountry
    public let literalBrowsingCountry: String
    public var imageResolution: ImageResolution
    public var imageSizeWidth: Float
    public var imageSizeHeight: Float
    public var galleryName: GalleryName
    public var archiverBehavior: ArchiverBehavior
    public var displayMode: DisplayMode
    public var showSearchRangeIndicator: Bool
    public var enableGalleryThumbnailSelector: Bool
    public var disabledCategories: [Bool]
    public var favoriteCategories: [String]
    public var favoritesSortOrder: FavoritesSortOrder
    public var ratingsColor: String
    public var tagFilteringThreshold: Float
    public var tagWatchingThreshold: Float
    public var showFilteredRemovalCount: Bool
    public var excludedLanguages: [Bool]
    public var excludedUploaders: String
    public var searchResultCount: SearchResultCount
    public var thumbnailLoadTiming: ThumbnailLoadTiming
    public var thumbnailConfigSize: ThumbnailSize
    public var thumbnailConfigRows: ThumbnailRowCount
    public var coverScaleFactor: Float
    public var viewportVirtualWidth: Float
    public var commentsSortOrder: CommentsSortOrder
    public var commentVotesShowTiming: CommentVotesShowTiming
    public var tagsSortOrder: TagsSortOrder
    public var galleryPageNumbering: GalleryPageNumbering
    public var useOriginalImages: Bool?
    public var useMultiplePageViewer: Bool?
    public var multiplePageViewerStyle: MultiplePageViewerStyle?
    public var multiplePageViewerShowThumbnailPane: Bool?

    public init(
        ehProfiles: [EhProfile],
        isCapableOfCreatingNewProfile: Bool,
        capableLoadThroughHathSetting: LoadThroughHathSetting,
        capableImageResolution: ImageResolution,
        capableSearchResultCount: SearchResultCount,
        capableThumbnailConfigRowCount: ThumbnailRowCount,
        capableThumbnailConfigSizes: [ThumbnailSize],
        loadThroughHathSetting: LoadThroughHathSetting,
        browsingCountry: BrowsingCountry,
        literalBrowsingCountry: String,
        imageResolution: ImageResolution,
        imageSizeWidth: Float,
        imageSizeHeight: Float,
        galleryName: GalleryName,
        archiverBehavior: ArchiverBehavior,
        displayMode: DisplayMode,
        showSearchRangeIndicator: Bool,
        enableGalleryThumbnailSelector: Bool,
        disabledCategories: [Bool],
        favoriteCategories: [String],
        favoritesSortOrder: FavoritesSortOrder,
        ratingsColor: String,
        tagFilteringThreshold: Float,
        tagWatchingThreshold: Float,
        showFilteredRemovalCount: Bool,
        excludedLanguages: [Bool],
        excludedUploaders: String,
        searchResultCount: SearchResultCount,
        thumbnailLoadTiming: ThumbnailLoadTiming,
        thumbnailConfigSize: ThumbnailSize,
        thumbnailConfigRows: ThumbnailRowCount,
        coverScaleFactor: Float,
        viewportVirtualWidth: Float,
        commentsSortOrder: CommentsSortOrder,
        commentVotesShowTiming: CommentVotesShowTiming,
        tagsSortOrder: TagsSortOrder,
        galleryPageNumbering: GalleryPageNumbering,
        useOriginalImages: Bool? = nil,
        useMultiplePageViewer: Bool? = nil,
        multiplePageViewerStyle: MultiplePageViewerStyle? = nil,
        multiplePageViewerShowThumbnailPane: Bool? = nil
    ) {
        self.ehProfiles = ehProfiles
        self.isCapableOfCreatingNewProfile = isCapableOfCreatingNewProfile
        self.capableLoadThroughHathSetting = capableLoadThroughHathSetting
        self.capableImageResolution = capableImageResolution
        self.capableSearchResultCount = capableSearchResultCount
        self.capableThumbnailConfigRowCount = capableThumbnailConfigRowCount
        self.capableThumbnailConfigSizes = capableThumbnailConfigSizes
        self.loadThroughHathSetting = loadThroughHathSetting
        self.browsingCountry = browsingCountry
        self.literalBrowsingCountry = literalBrowsingCountry
        self.imageResolution = imageResolution
        self.imageSizeWidth = imageSizeWidth
        self.imageSizeHeight = imageSizeHeight
        self.galleryName = galleryName
        self.archiverBehavior = archiverBehavior
        self.displayMode = displayMode
        self.showSearchRangeIndicator = showSearchRangeIndicator
        self.enableGalleryThumbnailSelector = enableGalleryThumbnailSelector
        self.disabledCategories = disabledCategories
        self.favoriteCategories = favoriteCategories
        self.favoritesSortOrder = favoritesSortOrder
        self.ratingsColor = ratingsColor
        self.tagFilteringThreshold = tagFilteringThreshold
        self.tagWatchingThreshold = tagWatchingThreshold
        self.showFilteredRemovalCount = showFilteredRemovalCount
        self.excludedLanguages = excludedLanguages
        self.excludedUploaders = excludedUploaders
        self.searchResultCount = searchResultCount
        self.thumbnailLoadTiming = thumbnailLoadTiming
        self.thumbnailConfigSize = thumbnailConfigSize
        self.thumbnailConfigRows = thumbnailConfigRows
        self.coverScaleFactor = coverScaleFactor
        self.viewportVirtualWidth = viewportVirtualWidth
        self.commentsSortOrder = commentsSortOrder
        self.commentVotesShowTiming = commentVotesShowTiming
        self.tagsSortOrder = tagsSortOrder
        self.galleryPageNumbering = galleryPageNumbering
        self.useOriginalImages = useOriginalImages
        self.useMultiplePageViewer = useMultiplePageViewer
        self.multiplePageViewerStyle = multiplePageViewerStyle
        self.multiplePageViewerShowThumbnailPane = multiplePageViewerShowThumbnailPane
    }
}

extension EhSetting {
    public static let empty = EhSetting(
        ehProfiles: [.empty], isCapableOfCreatingNewProfile: true,
        capableLoadThroughHathSetting: .anyClient, capableImageResolution: .auto,
        capableSearchResultCount: .fifty, capableThumbnailConfigRowCount: .forty,
        capableThumbnailConfigSizes: [], loadThroughHathSetting: .anyClient,
        browsingCountry: .autoDetect, literalBrowsingCountry: "", imageResolution: .auto,
        imageSizeWidth: 0, imageSizeHeight: 0, galleryName: .default,
        archiverBehavior: .autoSelectOriginalAutoStart, displayMode: .compact,
        showSearchRangeIndicator: true, enableGalleryThumbnailSelector: false,
        disabledCategories: Array(repeating: false, count: 10),
        favoriteCategories: Array(repeating: "", count: 10), favoritesSortOrder: .favoritedTime,
        ratingsColor: "", tagFilteringThreshold: 0, tagWatchingThreshold: 0,
        showFilteredRemovalCount: true, excludedLanguages: Array(repeating: false, count: 50),
        excludedUploaders: "", searchResultCount: .fifty, thumbnailLoadTiming: .onPageLoad,
        thumbnailConfigSize: .normal, thumbnailConfigRows: .ten, coverScaleFactor: 0,
        viewportVirtualWidth: 0, commentsSortOrder: .recent, commentVotesShowTiming: .always,
        tagsSortOrder: .alphabetical, galleryPageNumbering: .none
    )

    /// The site's form names for the category checkboxes, in `Category.allFiltersCases` order.
    public static let categoryNames = Category.allFiltersCases.map(\.rawValue).map { value in
        value.lowercased().replacingOccurrences(of: " ", with: "")
    }

    /// The site's form values for the excluded-language checkboxes: original, translated
    /// and rewrite for each language in `Language.allExcludedCases` order, except that
    /// Japanese has no "original" box. Indices match `excludedLanguages`.
    public static let languageValues = [
        1024, 2048, 1, 1025, 2049, 10, 1034, 2058,
        20, 1044, 2068, 30, 1054, 2078, 40, 1064, 2088,
        50, 1074, 2098, 60, 1084, 2108, 70, 1094, 2118,
        80, 1104, 2128, 90, 1114, 2138, 100, 1124, 2148,
        110, 1134, 2158, 120, 1144, 2168, 130, 1154, 2178,
        254, 1278, 2302, 255, 1279, 2303
    ]

    /// Whether `name` is one of the names the app gives its own profile.
    public static func verifyEhPandaProfileName(with name: String?) -> Bool {
        ["EhPanda", "EhPanda (Default)"].contains(name ?? "")
    }

    /// The profile the app created for itself, if any.
    public var ehpandaProfile: EhProfile? {
        ehProfiles.first(where: { EhSetting.verifyEhPandaProfileName(with: $0.name) })
    }

    public var capableLoadThroughHathSettings: [LoadThroughHathSetting] {
        LoadThroughHathSetting.allCases.filter { $0 <= capableLoadThroughHathSetting }
    }
    public var capableImageResolutions: [ImageResolution] {
        ImageResolution.allCases.filter { $0 <= capableImageResolution }
    }
    public var capableSearchResultCounts: [SearchResultCount] {
        SearchResultCount.allCases.filter { $0 <= capableSearchResultCount }
    }
    public var capableThumbnailConfigRowCounts: [ThumbnailRowCount] {
        ThumbnailRowCount.allCases.filter { $0 <= capableThumbnailConfigRowCount }
    }

    /// The country the site detected, matched against `BrowsingCountry.englishName`.
    public var literalBrowsingCountryValue: BrowsingCountry? {
        BrowsingCountry.allCases.first(where: { $0.englishName == literalBrowsingCountry })
    }
}

public typealias FavoritesSortOrder = EhSetting.FavoritesSortOrder
