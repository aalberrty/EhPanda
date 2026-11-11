import Foundation

// The site's select options. Raw values are the form values the site expects.

extension EhSetting {
    public enum LoadThroughHathSetting: Int, Sendable, CaseIterable, Identifiable, Comparable {
        case anyClient
        case defaultPortOnly
        case modernNo
        case legacyNo

        public var id: Int { rawValue }
        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public enum ImageResolution: Int, Sendable, CaseIterable, Identifiable, Comparable {
        case auto
        case x780
        /// Deprecated by the site.
        case x980
        case x1280
        case x1600
        case x2400

        public var id: Int { rawValue }
        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public enum GalleryName: Int, Sendable, CaseIterable, Identifiable {
        case `default`
        case japanese

        public var id: Int { rawValue }
    }

    public enum ArchiverBehavior: Int, Sendable, CaseIterable, Identifiable {
        case manualSelectManualStart
        case manualSelectAutoStart
        case autoSelectOriginalManualStart
        case autoSelectOriginalAutoStart
        case autoSelectResampleManualStart
        case autoSelectResampleAutoStart

        public var id: Int { rawValue }
    }

    public enum DisplayMode: Int, Sendable, CaseIterable, Identifiable {
        case compact
        case thumbnail
        case extended
        case minimal
        case minimalPlus

        public var id: Int { rawValue }
    }

    public enum FavoritesSortOrder: Int, Sendable, CaseIterable, Identifiable {
        case lastUpdateTime
        case favoritedTime

        public var id: Int { rawValue }
    }

    public enum ExcludedLanguagesCategory: Int, Sendable, CaseIterable, Identifiable {
        case original
        case translated
        case rewrite

        public var id: Int { rawValue }
    }

    public enum SearchResultCount: Int, Sendable, CaseIterable, Identifiable, Comparable {
        case twentyFive
        case fifty
        case oneHundred
        case twoHundred

        public var id: Int { rawValue }
        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public enum ThumbnailLoadTiming: Int, Sendable, CaseIterable, Identifiable {
        case onMouseOver
        case onPageLoad

        public var id: Int { rawValue }
    }

    public enum ThumbnailSize: Int, Sendable, CaseIterable, Identifiable, Comparable {
        case auto
        case small
        case normal
        /// Deprecated by the site.
        case large

        public var id: Int { rawValue }
        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public enum ThumbnailRowCount: Int, Sendable, CaseIterable, Identifiable, Comparable {
        case four
        case ten
        case twenty
        case forty

        public var id: Int { rawValue }
        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public enum CommentsSortOrder: Int, Sendable, CaseIterable, Identifiable {
        case oldest
        case recent
        case highestScore

        public var id: Int { rawValue }
    }

    public enum CommentVotesShowTiming: Int, Sendable, CaseIterable, Identifiable {
        case onHoverOrClick
        case always

        public var id: Int { rawValue }
    }

    public enum TagsSortOrder: Int, Sendable, CaseIterable, Identifiable {
        case alphabetical
        case tagPower

        public var id: Int { rawValue }
    }

    public enum MultiplePageViewerStyle: Int, Sendable, CaseIterable, Identifiable {
        case alignLeftScaleIfOverWidth
        case alignCenterScaleIfOverWidth
        case alignCenterAlwaysScale

        public var id: Int { rawValue }
    }

    public enum GalleryPageNumbering: Int, Sendable, CaseIterable, Identifiable {
        case none
        case pageNumberOnly
        case pageNumberAndName

        public var id: Int { rawValue }
    }
}
