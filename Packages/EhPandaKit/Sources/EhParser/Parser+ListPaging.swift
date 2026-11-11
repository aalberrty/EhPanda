import EhModels
import Foundation
import Kanna

// MARK: PageNumber

extension Parser {
    /// Paging of a list page: numbered (`table.ptt`, toplists) or timestamp based
    /// (`div.searchnav`, everything else).
    public static func parsePageNum(doc: HTMLDocument) -> PageNumber {
        var current = 0
        var maximum = 0

        guard let link = doc.at_xpath("//table [@class='ptt']"),
              let currentStr = link.at_xpath("//td [@class='ptds']")?.text
        else {
            if let link = doc.at_xpath("//div [@class='searchnav']") {
                var timestamp: String?
                var isEnabled = false

                for aLink in link.xpath("//a") where aLink.text?.contains("Next") == true {
                    timestamp = aLink["href"]
                        .flatMap(URLComponents.init(string:))?
                        .queryItems?
                        .first(where: { $0.name == QueryKey.next })?
                        .value?
                        .split(separator: "-")
                        .last
                        .map(String.init)

                    isEnabled = true
                    break
                }

                return PageNumber(lastItemTimestamp: timestamp, isNextButtonEnabled: isEnabled)
            } else {
                return PageNumber(isNextButtonEnabled: false)
            }
        }

        if let range = currentStr.range(of: "-") {
            current = (Int(currentStr[range.upperBound...]) ?? 1) - 1
        } else {
            current = (Int(currentStr) ?? 1) - 1
        }
        for aLink in link.xpath("//a") {
            if let num = Int(aLink.text ?? "") {
                maximum = num - 1
            }
        }
        return PageNumber(current: current, maximum: maximum)
    }
}

// MARK: SortOrder

extension Parser {
    /// The favorites page's current sort order, read from its "Use Posted / Use Favorited"
    /// toggle (which names the order you would switch to).
    public static func parseFavoritesSortOrder(doc: HTMLDocument) -> FavoritesSortOrder? {
        guard let idoNode = doc.at_xpath("//div [@class='ido']") else { return nil }
        for link in idoNode.xpath("//div") where link.className == nil {
            guard let aText = link.at_xpath("//div")?.at_xpath("//a")?.text else { continue }
            if aText == "Use Posted" {
                return .favoritedTime
            } else if aText == "Use Favorited" {
                return .lastUpdateTime
            }
        }
        return nil
    }
}
