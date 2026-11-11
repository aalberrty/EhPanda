import Foundation

/// The app's own preferences.
///
/// Decoding is tolerant (see the extension below): any missing or malformed key falls
/// back to its default, so preferences saved by older versions always load.
public struct Setting: Codable, Sendable, Equatable {
    // Account
    public var galleryHost: GalleryHost = .ehentai
    public var showsNewDawnGreeting = false

    // General
    public var enablesTagsExtension = false {
        didSet {
            if !enablesTagsExtension {
                translatesTags = false
                showsTagsSearchSuggestion = false
                showsImagesInTags = false
            }
        }
    }
    public var translatesTags = false
    public var showsTagsSearchSuggestion = false
    public var showsImagesInTags = false
    public var redirectsLinksToSelectedHost = false
    public var detectsLinksFromClipboard = false
    public var backgroundBlurRadius: Double = 10
    public var autoLockPolicy: AutoLockPolicy = .never

    // Appearance
    /// Legacy defaulted to `.thumbnail` on iPad-width screens; the app applies that
    /// default itself because this module cannot know the screen.
    public var listDisplayMode: ListDisplayMode = .detail
    public var preferredColorScheme: PreferredColorScheme = .automatic
    public var accentColor: RGBColor = .systemBlue
    public var appIconType: AppIconType = .default
    public var showsTagsInList = false
    public var listTagsNumberMaximum = 0
    public var displaysJapaneseTitle = true

    // Reading
    public var readingDirection: ReadingDirection = .vertical
    public var prefetchLimit = 10
    public var enablesLandscape = false
    public var enablesDualPageMode = false
    public var exceptCover = false
    public var contentDividerHeight: Double = 0
    public var maximumScaleFactor: Double = 3
    public var doubleTapScaleFactor: Double = 2

    // Laboratory
    public var bypassesSNIFiltering = false

    public init() {}
}

// MARK: Legacy decoding

extension Setting {
    /// Ported from the legacy app: every key is optional and a value that fails to decode
    /// is replaced by its default instead of failing the whole object.
    public init(from decoder: any Decoder) {
        let defaults = Setting()
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container?.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }

        // Account
        galleryHost = value(.galleryHost, defaults.galleryHost)
        showsNewDawnGreeting = value(.showsNewDawnGreeting, defaults.showsNewDawnGreeting)
        // General
        enablesTagsExtension = value(.enablesTagsExtension, defaults.enablesTagsExtension)
        translatesTags = value(.translatesTags, defaults.translatesTags)
        showsTagsSearchSuggestion = value(.showsTagsSearchSuggestion, defaults.showsTagsSearchSuggestion)
        showsImagesInTags = value(.showsImagesInTags, defaults.showsImagesInTags)
        redirectsLinksToSelectedHost = value(.redirectsLinksToSelectedHost, defaults.redirectsLinksToSelectedHost)
        detectsLinksFromClipboard = value(.detectsLinksFromClipboard, defaults.detectsLinksFromClipboard)
        backgroundBlurRadius = value(.backgroundBlurRadius, defaults.backgroundBlurRadius)
        autoLockPolicy = value(.autoLockPolicy, defaults.autoLockPolicy)
        // Appearance
        listDisplayMode = value(.listDisplayMode, defaults.listDisplayMode)
        preferredColorScheme = value(.preferredColorScheme, defaults.preferredColorScheme)
        accentColor = value(.accentColor, defaults.accentColor)
        appIconType = value(.appIconType, defaults.appIconType)
        showsTagsInList = value(.showsTagsInList, defaults.showsTagsInList)
        listTagsNumberMaximum = value(.listTagsNumberMaximum, defaults.listTagsNumberMaximum)
        displaysJapaneseTitle = value(.displaysJapaneseTitle, defaults.displaysJapaneseTitle)
        // Reading
        readingDirection = value(.readingDirection, defaults.readingDirection)
        prefetchLimit = value(.prefetchLimit, defaults.prefetchLimit)
        enablesLandscape = value(.enablesLandscape, defaults.enablesLandscape)
        enablesDualPageMode = value(.enablesDualPageMode, defaults.enablesDualPageMode)
        exceptCover = value(.exceptCover, defaults.exceptCover)
        contentDividerHeight = value(.contentDividerHeight, defaults.contentDividerHeight)
        maximumScaleFactor = value(.maximumScaleFactor, defaults.maximumScaleFactor)
        doubleTapScaleFactor = value(.doubleTapScaleFactor, defaults.doubleTapScaleFactor)
        // Laboratory
        bypassesSNIFiltering = value(.bypassesSNIFiltering, defaults.bypassesSNIFiltering)
    }
}
