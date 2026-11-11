import EhModels
import Foundation
import Kanna

// MARK: Greeting

extension Parser {
    /// The daily reward from the event pane ("You gain 30 EXP and 329 Credits!").
    ///
    /// - Parameter now: stored as `updateTime`; legacy used the current date.
    public static func parseGreeting(doc: HTMLDocument, now: Date = Date()) throws -> Greeting {
        guard let node = doc.at_xpath("//div [@id='eventpane']")
        else { throw AppError.parseFailed }

        var greeting = Greeting()
        for link in node.xpath("//p") {
            guard let text = link.text, text.contains("You gain") == true
            else { continue }

            var gainedValues = [String]()
            for strongLink in link.xpath("//strong") {
                if let strongText = strongLink.text {
                    gainedValues.append(strongText)
                }
            }

            let gainedTypes = gainedTypes(text: text, gainedValues: gainedValues)
            let gainedIntValues = gainedValues.compactMap(trimmedInt)
            guard gainedIntValues.count == gainedTypes.count
            else { throw AppError.parseFailed }

            for (index, type) in gainedTypes.enumerated() {
                let value = gainedIntValues[index]
                switch type {
                case "EXP":
                    greeting.gainedEXP = value
                case "Credits":
                    greeting.gainedCredits = value
                case "GP":
                    greeting.gainedGP = value
                case "Hath":
                    greeting.gainedHath = value
                default:
                    break
                }
            }
            break
        }

        greeting.updateTime = now
        return greeting
    }

    /// The unit after each value, found by consuming `text` up to each value in turn.
    private static func gainedTypes(text: String, gainedValues: [String]) -> [String] {
        var text = text
        var gainedTypes = [String]()
        for value in gainedValues {
            guard let range = text.range(of: value) else { break }
            let removeText = String(text[..<range.upperBound])

            if value != gainedValues.first {
                if let type = gainType(in: removeText) {
                    gainedTypes.append(type)
                }
            }

            text = text.replacingOccurrences(of: removeText, with: "")

            if value == gainedValues.last {
                if let type = gainType(in: text) {
                    gainedTypes.append(type)
                }
            }
        }
        return gainedTypes
    }

    private static func gainType(in string: String) -> String? {
        if string.contains("EXP") {
            return "EXP"
        } else if string.contains("Credits") {
            return "Credits"
        } else if string.contains("GP") {
            return "GP"
        } else if string.contains("Hath") {
            return "Hath"
        } else {
            return nil
        }
    }

    private static func trimmedInt(_ string: String) -> Int? {
        Int(string.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: ""))
    }
}
