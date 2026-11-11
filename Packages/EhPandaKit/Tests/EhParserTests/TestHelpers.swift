import EhParser
import EhTestSupport
import Foundation
import Kanna

/// Parses a fixture under `Fixtures/Parser/`, e.g. `"List/FrontPageMinimalList.html"`.
func parserFixture(_ path: String) throws -> HTMLDocument {
    try Parser.htmlDocument(data: Fixture.data("Parser/\(path)"))
}

/// Parses hand-written HTML.
func html(_ string: String) throws -> HTMLDocument {
    try Parser.htmlDocument(data: Data(string.utf8))
}

/// A UTC date, for asserting parsed site timestamps.
func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    )!
}
