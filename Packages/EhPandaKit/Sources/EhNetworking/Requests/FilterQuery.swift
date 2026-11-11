import EhModels
import Foundation

/// Turns a `Filter` into the site's search query items (legacy `URL.applyingFilter`).
///
/// Legacy collected the items in two dictionaries, values first, then switches, so the
/// order inside each group was unspecified. Here each group follows declaration order.
enum FilterQuery {
    static func items(for filter: Filter) -> [URLQueryItem] {
        var values = [URLQueryItem]()
        var switches = [URLQueryItem]()
        func value(_ key: RequestQueryKey, _ value: String) {
            values.append(RequestEncoding.item(key, value))
        }
        func on(_ key: RequestQueryKey, _ isOn: Bool = true) {
            if isOn { switches.append(RequestEncoding.item(key, RequestQueryValue.filterOn)) }
        }

        let categoryValue = categoryMask(filter)
        // Nothing and everything selected both mean "no category filter".
        if ![0, 1023].contains(categoryValue) {
            value(.fCats, String(categoryValue))
        }
        guard filter.advanced else { return values }
        switches.append(RequestEncoding.item(.advSearch, RequestQueryValue.one))

        on(.fSname, filter.galleryName)
        on(.fStags, filter.galleryTags)
        on(.fSdesc, filter.galleryDesc)
        on(.fStorr, filter.torrentFilenames)
        on(.fSto, filter.onlyWithTorrents)
        on(.fSdt1, filter.lowPowerTags)
        on(.fSdt2, filter.downvotedTags)
        on(.fSh, filter.expungedGalleries)

        if filter.minRatingActivated, [2, 3, 4, 5].contains(filter.minRating) {
            on(.fSr)
            value(.fSrdd, String(filter.minRating))
        }
        if filter.pageRangeActivated {
            on(.fSp)
            for (key, pages) in pageRange(filter) {
                value(key, String(pages))
            }
        }

        on(.fSfl, filter.disableLanguage)
        on(.fSfu, filter.disableUploader)
        on(.fSft, filter.disableTags)
        return values + switches
    }

    private static func categoryMask(_ filter: Filter) -> Int {
        let flags: [(Bool, EhModels.Category)] = [
            (filter.doujinshi, .doujinshi), (filter.manga, .manga),
            (filter.artistCG, .artistCG), (filter.gameCG, .gameCG),
            (filter.western, .western), (filter.nonH, .nonH),
            (filter.imageSet, .imageSet), (filter.cosplay, .cosplay),
            (filter.asianPorn, .asianPorn), (filter.misc, .misc)
        ]
        return flags.reduce(0) { $0 + ($1.0 ? $1.1.filterValue : 0) }
    }

    /// When both bounds parse, both are sent only if they form a valid positive range;
    /// an invalid pair sends neither (legacy did not fall back to a single bound).
    private static func pageRange(_ filter: Filter) -> [(RequestQueryKey, Int)] {
        switch (Int(filter.pageLowerBound), Int(filter.pageUpperBound)) {
        case let (.some(minPages), .some(maxPages)):
            guard minPages > 0, maxPages > 0, minPages <= maxPages else { return [] }
            return [(.fSpf, minPages), (.fSpt, maxPages)]
        case let (.some(minPages), .none):
            return minPages > 0 ? [(.fSpf, minPages)] : []
        case let (.none, .some(maxPages)):
            return maxPages > 0 ? [(.fSpt, maxPages)] : []
        case (.none, .none):
            return []
        }
    }
}
