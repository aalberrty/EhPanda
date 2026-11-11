/// How often auto-play turns the page (legacy `AutoPlayPolicy`).
nonisolated public enum ReaderAutoPlayPolicy: Int, Sendable, Hashable, CaseIterable, Identifiable {
    case off = -1
    case oneSecond = 1
    case twoSeconds = 2
    case threeSeconds = 3
    case fourSeconds = 4
    case fiveSeconds = 5

    public var id: Int { rawValue }

    /// Seconds between page turns, or `nil` when off.
    public var seconds: Int? { rawValue > 0 ? rawValue : nil }
}

/// What the context menu of a page offers (legacy `ReadingView` context menu).
nonisolated public enum ReaderImageAction: Sendable, Hashable, CaseIterable {
    /// Fetch the page's image again through another image server.
    case reload
    case copy
    case save
    /// Save the full-resolution image, offered when the site has one.
    case saveOriginal
    case share
}
