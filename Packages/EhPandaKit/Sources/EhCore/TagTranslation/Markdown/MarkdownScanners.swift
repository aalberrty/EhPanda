import Foundation

/// Byte classes and fixed-pattern scanners shared by the block and inline parsers.
///
/// Ported from cmark 0.30.2 (`scanners.re`, `cmark_ctype.c`, `utf8.c`), the version legacy's
/// SwiftCommonMark bundled. Every scanner takes the whole line or subject plus an offset and
/// returns the number of bytes matched, `0` meaning no match.
enum MarkdownScan {
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let space = UInt8(ascii: " ")
    static let tab = UInt8(ascii: "\t")

    /// `cmark_isspace`.
    static func isSpace(_ byte: UInt8) -> Bool {
        byte == 0x20 || (0x09...0x0D).contains(byte)
    }

    /// `cmark_ispunct`: ASCII punctuation and symbols.
    static func isASCIIPunctuation(_ byte: UInt8) -> Bool {
        (0x21...0x2F).contains(byte) || (0x3A...0x40).contains(byte)
            || (0x5B...0x60).contains(byte) || (0x7B...0x7E).contains(byte)
    }

    static func isLineEnd(_ byte: UInt8?) -> Bool {
        byte == newline || byte == carriageReturn
    }

    static func isSpaceOrTab(_ byte: UInt8?) -> Bool {
        byte == space || byte == tab
    }

    static func isDigit(_ byte: UInt8) -> Bool { (0x30...0x39).contains(byte) }

    static func isLetter(_ byte: UInt8) -> Bool {
        (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
    }

    static func isAlphanumeric(_ byte: UInt8) -> Bool { isLetter(byte) || isDigit(byte) }

    /// `cmark_utf8proc_is_space`.
    static func isUnicodeSpace(_ scalar: UInt32) -> Bool {
        [9, 10, 12, 13, 32, 160, 5760, 8239, 8287, 12288].contains(scalar) || (8192...8202).contains(scalar)
    }

    /// `cmark_utf8proc_is_punctuation`: ASCII punctuation or a Unicode `P*` category.
    static func isUnicodePunctuation(_ scalar: UInt32) -> Bool {
        if scalar < 128 { return isASCIIPunctuation(UInt8(scalar)) }
        guard let scalar = Unicode.Scalar(scalar) else { return false }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }

    // MARK: Pattern scanners

    /// `spacechar*`, newlines included.
    static func spaceChars(_ input: [UInt8], _ offset: Int) -> Int {
        var index = offset
        while index < input.count, isSpace(input[index]) { index += 1 }
        return index - offset
    }

    /// `["] (escaped_char|[^"])* ["]`, the single-quote form, or `[(] (escaped_char|[^()])* [)]`,
    /// longest match. A backslash may stand for itself, so a closer preceded by one may also be
    /// content; an unescaped opener inside the parenthesised form ends the scan.
    static func linkTitle(_ input: [UInt8], _ offset: Int) -> Int {
        guard offset < input.count else { return 0 }
        let open = input[offset]
        let close: UInt8
        switch open {
        case UInt8(ascii: "\""), UInt8(ascii: "'"): close = open
        case UInt8(ascii: "("): close = UInt8(ascii: ")")
        default: return 0
        }
        var longest = 0
        var index = offset + 1
        while index < input.count, input[index] != 0 {
            let byte = input[index]
            let escaped = input[index - 1] == UInt8(ascii: "\\") && index - 1 > offset
            if byte == close {
                longest = index + 1 - offset
                if !escaped { break }
            } else if open == UInt8(ascii: "("), byte == open, !escaped {
                break
            }
            index += 1
        }
        return longest
    }

    /// `[A-Za-z][A-Za-z0-9-]*`.
    static func tagName(_ input: [UInt8], _ offset: Int) -> Int {
        guard offset < input.count, isLetter(input[offset]) else { return 0 }
        var index = offset + 1
        while index < input.count, isAlphanumeric(input[index]) || input[index] == UInt8(ascii: "-") { index += 1 }
        return index - offset
    }

    /// `opentag | closetag` after the `<`.
    static func htmlTag(_ input: [UInt8], _ offset: Int) -> Int {
        guard offset < input.count else { return 0 }
        if input[offset] == UInt8(ascii: "/") {
            let name = tagName(input, offset + 1)
            guard name > 0 else { return 0 }
            var index = offset + 1 + name
            index += spaceChars(input, index)
            return index < input.count && input[index] == UInt8(ascii: ">") ? index + 1 - offset : 0
        }
        let name = tagName(input, offset)
        guard name > 0 else { return 0 }
        var index = offset + name
        while let length = attribute(input, index) { index += length }
        index += spaceChars(input, index)
        if index < input.count, input[index] == UInt8(ascii: "/") { index += 1 }
        return index < input.count && input[index] == UInt8(ascii: ">") ? index + 1 - offset : 0
    }

    /// `spacechar+ attributename attributevaluespec?`.
    private static func attribute(_ input: [UInt8], _ offset: Int) -> Int? {
        let spaces = spaceChars(input, offset)
        var index = offset + spaces
        guard spaces > 0, index < input.count else { return nil }
        let first = input[index]
        guard isLetter(first) || first == UInt8(ascii: "_") || first == UInt8(ascii: ":") else { return nil }
        index += 1
        while index < input.count, isAlphanumeric(input[index]) || ":._-".utf8.contains(input[index]) { index += 1 }
        // attributevaluespec = spacechar* [=] spacechar* attributevalue
        var valueIndex = index + spaceChars(input, index)
        if valueIndex < input.count, input[valueIndex] == UInt8(ascii: "=") {
            valueIndex += 1
            valueIndex += spaceChars(input, valueIndex)
            if let length = attributeValue(input, valueIndex) { index = valueIndex + length }
        }
        return index - offset
    }

    private static func attributeValue(_ input: [UInt8], _ offset: Int) -> Int? {
        guard offset < input.count else { return nil }
        let first = input[offset]
        if first == UInt8(ascii: "'") || first == UInt8(ascii: "\"") {
            var index = offset + 1
            while index < input.count, input[index] != first, input[index] != 0 { index += 1 }
            return index < input.count && input[index] == first ? index + 1 - offset : nil
        }
        var index = offset
        while index < input.count, !" \t\r\n\u{0B}\u{0C}\"'=<>`\0".utf8.contains(input[index]) { index += 1 }
        return index > offset ? index - offset : nil
    }

    /// `scheme [:] [^\x00-\x20<>]* [>]` after the `<`.
    static func autolinkURI(_ input: [UInt8], _ offset: Int) -> Int {
        guard offset < input.count, isLetter(input[offset]) else { return 0 }
        var index = offset + 1
        while index < input.count, isAlphanumeric(input[index]) || ".+-".utf8.contains(input[index]) { index += 1 }
        let schemeLength = index - offset
        guard (2...32).contains(schemeLength), index < input.count, input[index] == UInt8(ascii: ":") else { return 0 }
        index += 1
        while index < input.count, input[index] > 0x20, input[index] != UInt8(ascii: "<"),
              input[index] != UInt8(ascii: ">") {
            index += 1
        }
        return index < input.count && input[index] == UInt8(ascii: ">") ? index + 1 - offset : 0
    }

    /// The email autolink form after the `<`.
    static func autolinkEmail(_ input: [UInt8], _ offset: Int) -> Int {
        var index = offset
        let localChars = Set(".!#$%&'*+/=?^_`{|}~-".utf8)
        while index < input.count, isAlphanumeric(input[index]) || localChars.contains(input[index]) { index += 1 }
        guard index > offset, index < input.count, input[index] == UInt8(ascii: "@") else { return 0 }
        index += 1
        while true {
            guard let label = domainLabel(input, index) else { return 0 }
            index += label
            guard index < input.count else { return 0 }
            if input[index] == UInt8(ascii: ">") { return index + 1 - offset }
            guard input[index] == UInt8(ascii: ".") else { return 0 }
            index += 1
        }
    }

    /// `[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?`, longest match ending in an alphanumeric.
    private static func domainLabel(_ input: [UInt8], _ offset: Int) -> Int? {
        guard offset < input.count, isAlphanumeric(input[offset]) else { return nil }
        var index = offset + 1
        var lastAlphanumeric = index
        while index < input.count, index - offset < 63,
              isAlphanumeric(input[index]) || input[index] == UInt8(ascii: "-") {
            index += 1
            if isAlphanumeric(input[index - 1]) { lastAlphanumeric = index }
        }
        return lastAlphanumeric - offset
    }

    /// The bytes of `input` starting at `offset` equal `literal`, ASCII-case-insensitively.
    static func hasPrefix(_ input: [UInt8], _ offset: Int, _ literal: String, caseInsensitive: Bool = false) -> Bool {
        var index = offset
        for expected in literal.utf8 {
            guard index < input.count else { return false }
            let actual = input[index]
            let matches = caseInsensitive && isLetter(actual) ? actual | 0x20 == expected | 0x20 : actual == expected
            guard matches else { return false }
            index += 1
        }
        return true
    }

    /// The first occurrence of `literal` in `input[offset...]` before the next newline.
    static func lineContains(_ input: [UInt8], _ offset: Int, _ literal: String) -> Bool {
        var index = offset
        while index < input.count, input[index] != newline {
            if hasPrefix(input, index, literal) { return true }
            index += 1
        }
        return false
    }
}
