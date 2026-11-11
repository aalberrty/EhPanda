import EhModels
import Foundation

extension DateFormattable {
    /// Short date and time in the user's locale, e.g. "11/10/26, 3:04 PM".
    var formattedDateString: String {
        originalDate.formatted(
            .dateTime.year(.twoDigits).month(.defaultDigits).day(.defaultDigits).hour().minute()
        )
    }
}
