import EhModels

/// One independently loaded part of the Home screen.
nonisolated public enum HomeSection: Hashable, Sendable {
    case popular
    case frontpage
    case toplists(ToplistsType)

    /// Every section, in the order they are requested.
    public static let all: [HomeSection] = [.popular, .frontpage] + toplists

    public static let toplists: [HomeSection] = ToplistsType.allCases.map(HomeSection.toplists)

    /// The key of the section's load in `ModelTasks`.
    var taskKey: String {
        switch self {
        case .popular: "popular"
        case .frontpage: "frontpage"
        case .toplists(let type): "toplists.\(type.rawValue)"
        }
    }
}

/// The selection, ordering and de-duplication rules of the Home sections (legacy `HomeReducer`
/// and `HomeView`). Pure, so the rules are tested without loading anything.
nonisolated public enum HomeSections {
    public static let maximumCards = 6
    static let cardCandidates = 10
    static let maximumFrontpage = 25
    /// The Frontpage wall shows two rows, as drawn; the full list is one tap away.
    public static let frontpageWallRows = 2

    /// Popular galleries shown in the pager: the 10 longest titles, de-duplicated by trimmed
    /// title, at most 6, shuffled.
    public static func cards(
        from galleries: [Gallery], using generator: inout some RandomNumberGenerator
    ) -> [Gallery] {
        // Ties keep the server's order, so the result depends only on the generator.
        let longestTitles = galleries.enumerated()
            .sorted { lhs, rhs in
                lhs.element.title.count != rhs.element.title.count
                    ? lhs.element.title.count > rhs.element.title.count
                    : lhs.offset < rhs.offset
            }
            .prefix(cardCandidates)
            .map(\.element)
        var cards = Array(uniqueByTrimmedTitle(longestTitles).prefix(maximumCards))
        cards.shuffle(using: &generator)
        return cards
    }

    /// The page the Popular pager opens on: the second one, as in legacy, when there is one.
    public static func initialCardIndex(count: Int) -> Int? {
        count == 0 ? nil : min(1, count - 1)
    }

    /// The page the Popular pager shows after its galleries change from `oldIDs` to `ids`: the
    /// current page while the set is the same (refreshed fields, or the screen reappearing),
    /// otherwise the opening page of the new set.
    public static func pagerPage(current: String?, oldIDs: [String], ids: [String]) -> String? {
        if oldIDs == ids, let current, ids.contains(current) { return current }
        return initialCardIndex(count: ids.count).map { ids[$0] }
    }

    /// The title shown under the Popular pager. Narrow layouts (legacy: iPhone) use the trimmed
    /// title when it is longer than 20 characters; otherwise the full title.
    public static func cardTitle(of gallery: Gallery, isCompact: Bool) -> String {
        let trimmed = gallery.trimmedTitle
        return isCompact && trimmed.count > 20 ? trimmed : gallery.title
    }

    /// Frontpage galleries kept for the wall: the first 25, de-duplicated by trimmed title.
    public static func frontpage(from galleries: [Gallery]) -> [Gallery] {
        uniqueByTrimmedTitle(Array(galleries.prefix(maximumFrontpage)))
    }

    /// The galleries of the Frontpage wall: at most `rows` rows of `columns`. A partly filled
    /// last row is dropped once there is a full row, so the wall ends on an even edge; "Show all"
    /// opens the rest.
    public static func frontpageWall(
        from galleries: [Gallery], columns: Int, rows: Int = frontpageWallRows
    ) -> [Gallery] {
        guard columns > 0, rows > 0 else { return [] }
        let shown = galleries.prefix(columns * rows)
        guard shown.count > columns else { return Array(shown) }
        return Array(shown.prefix(shown.count / columns * columns))
    }

    /// The title of a small cover or a toplists row: the trimmed title, or the full one when
    /// trimming leaves nothing (a title made only of bracketed groups).
    public static func shortTitle(of gallery: Gallery) -> String {
        let trimmed = gallery.trimmedTitle
        return trimmed.isEmpty ? gallery.title : trimmed
    }

    /// The ranked rows of one toplists column: ranks `ranks` (1-based) of `galleries`.
    public static func ranking(_ galleries: [Gallery], ranks: ClosedRange<Int>) -> [RankedGallery] {
        ranks.compactMap { rank in
            galleries.indices.contains(rank - 1) ? RankedGallery(rank: rank, gallery: galleries[rank - 1]) : nil
        }
    }

    static func uniqueByTrimmedTitle(_ galleries: [Gallery]) -> [Gallery] {
        var seen = Set<String>()
        return galleries.filter { seen.insert($0.trimmedTitle).inserted }
    }
}

/// A toplists row: the gallery and its rank in the period.
nonisolated public struct RankedGallery: Identifiable, Hashable, Sendable {
    public let rank: Int
    public let gallery: Gallery

    public var id: Int { rank }
}
