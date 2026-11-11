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

/// Two frontpage covers stacked in one column of the cover strip.
nonisolated public struct CoverColumn: Identifiable, Hashable, Sendable {
    public let top: Gallery
    public let bottom: Gallery

    public var id: String { top.id }
}

/// The selection, ordering and de-duplication rules of the Home sections (legacy `HomeReducer`
/// and `HomeView`). Pure, so the rules are tested without loading anything.
nonisolated public enum HomeSections {
    public static let maximumCards = 6
    static let cardCandidates = 10
    static let maximumFrontpage = 25

    /// Popular galleries shown as cards: the 10 longest titles, de-duplicated by trimmed title,
    /// at most 6, shuffled.
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

    /// The card the carousel opens on: the second one, as in legacy, when there is one.
    public static func initialCardIndex(count: Int) -> Int? {
        count == 0 ? nil : min(1, count - 1)
    }

    /// The title a card shows. Narrow layouts (legacy: iPhone) use the trimmed title when it
    /// is longer than 20 characters; otherwise the full title.
    public static func cardTitle(of gallery: Gallery, isCompact: Bool) -> String {
        let trimmed = gallery.trimmedTitle
        return isCompact && trimmed.count > 20 ? trimmed : gallery.title
    }

    /// Frontpage galleries kept for the cover strip: the first 25, de-duplicated by trimmed title.
    public static func frontpage(from galleries: [Gallery]) -> [Gallery] {
        uniqueByTrimmedTitle(Array(galleries.prefix(maximumFrontpage)))
    }

    /// The cover strip shows galleries in columns of two; an odd last gallery is dropped.
    public static func coverColumns(from galleries: [Gallery]) -> [CoverColumn] {
        stride(from: 0, to: galleries.count - 1, by: 2).map { index in
            CoverColumn(top: galleries[index], bottom: galleries[index + 1])
        }
    }

    /// Legacy showed the strip only with at least two galleries, i.e. one full column.
    public static func showsCoverStrip(galleryCount: Int) -> Bool {
        galleryCount > 1
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
