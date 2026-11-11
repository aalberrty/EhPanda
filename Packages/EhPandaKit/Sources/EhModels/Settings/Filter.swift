import Foundation

/// A gallery search filter. The app keeps three: for searches, for every list, and for
/// the watched list (see `FilterRange`).
public struct Filter: Codable, Sendable, Equatable {
    public var doujinshi = false
    public var manga = false
    public var artistCG = false
    public var gameCG = false
    public var western = false
    public var nonH = false
    public var imageSet = false
    public var cosplay = false
    public var asianPorn = false
    public var misc = false

    public var advanced = false
    public var galleryName = true
    public var galleryTags = true
    public var galleryDesc = false
    public var torrentFilenames = false
    public var onlyWithTorrents = false
    // Low-power and downvoted tags are mutually exclusive on the site.
    public var lowPowerTags = false {
        didSet {
            if lowPowerTags {
                downvotedTags = false
            }
        }
    }
    public var downvotedTags = false {
        didSet {
            if downvotedTags {
                lowPowerTags = false
            }
        }
    }
    public var expungedGalleries = false

    public var minRatingActivated = false
    public var minRating = 2

    public var pageRangeActivated = false
    public var pageLowerBound = ""
    public var pageUpperBound = ""

    public var disableLanguage = false
    public var disableUploader = false
    public var disableTags = false

    public init() {}

    /// Clears page bounds that are not whole numbers.
    public mutating func fixInvalidData() {
        if !pageLowerBound.isEmpty && Int(pageLowerBound) == nil {
            pageLowerBound = ""
        }
        if !pageUpperBound.isEmpty && Int(pageUpperBound) == nil {
            pageUpperBound = ""
        }
    }
}

// MARK: Legacy decoding

extension Filter {
    /// Ported from the legacy app: a missing or malformed key decodes as its fallback.
    ///
    /// Unlike `init()`, the fallback for `galleryName` and `galleryTags` is `false`;
    /// that quirk is kept so legacy data decodes exactly as it did before.
    public init(from decoder: any Decoder) {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container?.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }

        doujinshi = value(.doujinshi, false)
        manga = value(.manga, false)
        artistCG = value(.artistCG, false)
        gameCG = value(.gameCG, false)
        western = value(.western, false)
        nonH = value(.nonH, false)
        imageSet = value(.imageSet, false)
        cosplay = value(.cosplay, false)
        asianPorn = value(.asianPorn, false)
        misc = value(.misc, false)

        advanced = value(.advanced, false)
        galleryName = value(.galleryName, false)
        galleryTags = value(.galleryTags, false)
        galleryDesc = value(.galleryDesc, false)
        torrentFilenames = value(.torrentFilenames, false)
        onlyWithTorrents = value(.onlyWithTorrents, false)
        lowPowerTags = value(.lowPowerTags, false)
        downvotedTags = value(.downvotedTags, false)
        expungedGalleries = value(.expungedGalleries, false)

        minRatingActivated = value(.minRatingActivated, false)
        minRating = value(.minRating, 2)

        pageRangeActivated = value(.pageRangeActivated, false)
        pageLowerBound = value(.pageLowerBound, "")
        pageUpperBound = value(.pageUpperBound, "")

        disableLanguage = value(.disableLanguage, false)
        disableUploader = value(.disableUploader, false)
        disableTags = value(.disableTags, false)
    }
}
