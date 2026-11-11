import EhModels
import Foundation
import Kanna

/// Scrapes E-Hentai pages and decodes its API responses into `EhModels` values.
///
/// Every function is pure: no network, no globals, no shared mutable state. The client
/// calls them off the main actor. Kanna documents are not `Sendable`, so a document must be
/// created and parsed in the same task.
public enum Parser {}

// MARK: Document

extension Parser {
    /// Turns a response body into an HTML document, as legacy requests did with
    /// `Kanna.HTML(html:encoding: .utf8)`.
    ///
    /// - Parameter recoversInvalidUTF8: when the body is not valid UTF-8, retry with invalid
    ///   sequences replaced. Legacy only did this for the gallery detail page.
    /// - Throws: `AppError.parseFailed` when the body cannot be read as HTML.
    public static func htmlDocument(data: Data, recoversInvalidUTF8: Bool = false) throws -> HTMLDocument {
        do {
            return try Kanna.HTML(html: data, encoding: .utf8)
        } catch ParseError.EncodingMismatch where recoversInvalidUTF8 {
            guard let document = try? Kanna.HTML(html: data.utf8InvalidCharactersRipped, encoding: .utf8)
            else { throw AppError.parseFailed }
            return document
        } catch {
            throw AppError.parseFailed
        }
    }
}

// MARK: Date

extension Parser {
    /// Parses a site timestamp, which is always UTC and English.
    public static func parseDate(time: String, format: String) throws -> Date {
        guard let date = DateFormatters.formatter(format: format).date(from: time)
        else { throw AppError.parseFailed }
        return date
    }
}

// MARK: Rating

extension Parser {
    /// Returns ratings parsed from stars image / text and if the return contains a userRating.
    public static func parseRating(node: Kanna.XMLElement) throws -> (Float, Float?, Bool) {
        func parseTextRating(node: Kanna.XMLElement) throws -> Float {
            guard let ratingString = node
                .at_xpath("//td [@id='rating_label']")?.text?
                .replacingOccurrences(of: "Average: ", with: "")
                .replacingOccurrences(of: "Not Yet Rated", with: "0"),
                let rating = Float(ratingString)
            else { throw AppError.parseFailed }

            return rating
        }

        var tmpRatingString: String?
        var containsUserRating = false

        for link in node.xpath("//div") where
            link.className?.contains("ir") == true
            && link["style"]?.isEmpty == false
        {
            if tmpRatingString != nil { break }
            tmpRatingString = link["style"]
            containsUserRating = link.className != "ir"
        }

        guard let ratingString = tmpRatingString
        else { throw AppError.parseFailed }

        var tmpRating: Float?
        if ratingString.contains("0px") { tmpRating = 5.0 }
        if ratingString.contains("-16px") { tmpRating = 4.0 }
        if ratingString.contains("-32px") { tmpRating = 3.0 }
        if ratingString.contains("-48px") { tmpRating = 2.0 }
        if ratingString.contains("-64px") { tmpRating = 1.0 }
        if ratingString.contains("-80px") { tmpRating = 0.0 }

        guard var rating = tmpRating
        else { throw AppError.parseFailed }

        if ratingString.contains("-21px") { rating -= 0.5 }
        return (rating, try? parseTextRating(node: node), containsUserRating)
    }
}
