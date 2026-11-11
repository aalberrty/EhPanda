import EhModels
import Foundation
import Kanna

// MARK: Ban

extension Parser {
    /// The ban length from an "IP banned" page, or `nil` when the page is not one.
    public static func parseBanInterval(doc: HTMLDocument) -> BanInterval? {
        guard let text = doc.body?.text, let range = text.range(of: "The ban expires in ")
        else { return nil }

        return parseBanInterval(expireDescription: String(text[range.upperBound...]))
    }

    static func parseBanInterval(expireDescription: String) -> BanInterval {
        if let days = leadingNumber(expireDescription, before: "days") {
            return .days(days, hours: andNumber(expireDescription, before: "hours"))
        } else if let hours = leadingNumber(expireDescription, before: "hours") {
            return .hours(hours, minutes: andNumber(expireDescription, before: "minutes"))
        } else if let minutes = leadingNumber(expireDescription, before: "minutes") {
            return .minutes(minutes, seconds: andNumber(expireDescription, before: "seconds"))
        } else {
            return .unrecognized(content: expireDescription)
        }
    }

    /// `"3 days and …"`, `"days"` → `3`.
    private static func leadingNumber(_ text: String, before unit: String) -> Int? {
        guard let unitRange = text.range(of: unit) else { return nil }
        return Int(text[..<unitRange.lowerBound].trimmingCharacters(in: .whitespaces))
    }

    /// `"… and 5 hours"`, `"hours"` → `5`.
    private static func andNumber(_ text: String, before unit: String) -> Int? {
        guard let andRange = text.range(of: "and"),
              let unitRange = text.range(of: unit),
              andRange.upperBound <= unitRange.lowerBound
        else { return nil }
        return Int(text[andRange.upperBound..<unitRange.lowerBound].trimmingCharacters(in: .whitespaces))
    }
}
