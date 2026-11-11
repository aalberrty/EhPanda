import Foundation

// MARK: Emphasis (`process_emphasis`, `S_insert_emph`)

extension MarkdownInlineParser {
    mutating func processEmphasis(stackBottom: Int) {
        var openersBottom = [Int](repeating: stackBottom, count: 9)
        var closer: Delimiter?
        var candidate = lastDelimiter
        while let current = candidate, current.position >= stackBottom {
            closer = current
            candidate = current.previous
        }

        while let currentCloser = closer {
            guard currentCloser.canClose else {
                closer = currentCloser.next
                continue
            }
            let bottomIndex = currentCloser.character == UInt8(ascii: "_")
                ? 2 : 3 + (currentCloser.canOpen ? 3 : 0) + currentCloser.length % 3
            var opener = currentCloser.previous
            var openerFound = false
            while let current = opener, current.position >= openersBottom[bottomIndex] {
                if current.canOpen, current.character == currentCloser.character,
                   !(currentCloser.canOpen || current.canClose) || currentCloser.length % 3 == 0
                    || (current.length + currentCloser.length) % 3 != 0 {
                    openerFound = true
                    break
                }
                opener = current.previous
            }
            if openerFound, let opener {
                closer = insertEmphasis(opener: opener, closer: currentCloser)
            } else {
                closer = currentCloser.next
                openersBottom[bottomIndex] = currentCloser.position
                if !currentCloser.canOpen { removeDelimiter(currentCloser) }
            }
        }
        while let delimiter = lastDelimiter, delimiter.position >= stackBottom {
            removeDelimiter(delimiter)
        }
    }

    /// Wraps the nodes between `opener` and `closer` in one emphasis node and returns the
    /// delimiter to continue from.
    private mutating func insertEmphasis(opener: Delimiter, closer: Delimiter) -> Delimiter? {
        let used = opener.node.bytes.count >= 2 && closer.node.bytes.count >= 2 ? 2 : 1
        opener.node.bytes.removeLast(used)
        closer.node.bytes.removeLast(used)

        var between = closer.previous
        while let delimiter = between, delimiter !== opener {
            between = delimiter.previous
            removeDelimiter(delimiter)
        }
        if let openerIndex = nodes.firstIndex(where: { $0 === opener.node }),
           let closerIndex = nodes.firstIndex(where: { $0 === closer.node }) {
            nodes.replaceSubrange(openerIndex + 1..<closerIndex, with: [Node(.other)])
        }

        if opener.node.bytes.isEmpty {
            nodes.removeAll { $0 === opener.node }
            removeDelimiter(opener)
        }
        if closer.node.bytes.isEmpty {
            nodes.removeAll { $0 === closer.node }
            let next = closer.next
            removeDelimiter(closer)
            return next
        }
        return closer
    }

    mutating func removeDelimiter(_ delimiter: Delimiter) {
        if let next = delimiter.next {
            next.previous = delimiter.previous
        } else {
            lastDelimiter = delimiter.previous
        }
        delimiter.previous?.next = delimiter.next
    }
}

// MARK: Link destinations and titles

enum MarkdownLinkDestination {
    /// `manual_scan_link_url`: the destination's content range and the bytes consumed.
    static func scan(_ input: [UInt8], _ offset: Int) -> (Range<Int>, Int)? {
        var index = offset
        if index < input.count, input[index] == UInt8(ascii: "<") {
            index += 1
            while index < input.count {
                let byte = input[index]
                if byte == UInt8(ascii: ">") {
                    index += 1
                    guard index < input.count else { return nil }
                    return ((offset + 1)..<(index - 1), index - offset)
                } else if byte == UInt8(ascii: "\\") {
                    index += 2
                } else if byte == MarkdownScan.newline || byte == UInt8(ascii: "<") {
                    return nil
                } else {
                    index += 1
                }
            }
            return nil
        }
        var depth = 0
        while index < input.count {
            let byte = input[index]
            if byte == UInt8(ascii: "\\"), index + 1 < input.count, MarkdownScan.isASCIIPunctuation(input[index + 1]) {
                index += 2
            } else if byte == UInt8(ascii: "(") {
                depth += 1
                index += 1
                if depth > 32 { return nil }
            } else if byte == UInt8(ascii: ")") {
                if depth == 0 { break }
                depth -= 1
                index += 1
            } else if MarkdownScan.isSpace(byte) {
                if index == offset { return nil }
                break
            } else {
                index += 1
            }
        }
        guard index < input.count, depth == 0 else { return nil }
        return (offset..<index, index - offset)
    }

    /// `cmark_clean_url`.
    static func clean(_ url: [UInt8]) -> [UInt8] {
        unescapeBackslashes(MarkdownEntities.unescapeHTML(MarkdownInlineParser.trimmed(url)))
    }

    /// `cmark_clean_title`.
    static func cleanTitle(_ title: [UInt8]) -> [UInt8] {
        guard let first = title.first, let last = title.last else { return [] }
        let isDelimited = title.count >= 2 && (
            (first == UInt8(ascii: "'") && last == first) || (first == UInt8(ascii: "\"") && last == first)
                || (first == UInt8(ascii: "(") && last == UInt8(ascii: ")"))
        )
        let content = isDelimited ? Array(title[1..<title.count - 1]) : title
        return unescapeBackslashes(MarkdownEntities.unescapeHTML(content))
    }

    /// `cmark_strbuf_unescape`.
    static func unescapeBackslashes(_ bytes: [UInt8]) -> [UInt8] {
        var result = [UInt8]()
        result.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "\\"), index + 1 < bytes.count,
               MarkdownScan.isASCIIPunctuation(bytes[index + 1]) {
                index += 1
            }
            result.append(bytes[index])
            index += 1
        }
        return result
    }
}

// MARK: Entities (`houdini_html_u.c`)

enum MarkdownEntities {
    /// Named entities cmark would decode. cmark knows the full HTML5 list; this keeps the ones
    /// plausibly written in tag descriptions. Others stay literal (the database has none).
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{A0}",
        "copy": "©", "reg": "®", "trade": "™", "hellip": "…", "mdash": "—", "ndash": "–",
        "middot": "·", "times": "×", "divide": "÷", "deg": "°", "plusmn": "±", "laquo": "«",
        "raquo": "»", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "bull": "•",
        "hearts": "♥", "star": "☆", "starf": "★", "larr": "←", "rarr": "→", "uarr": "↑",
        "darr": "↓", "sect": "§", "para": "¶", "yen": "¥", "euro": "€", "pound": "£", "cent": "¢"
    ]

    /// Decodes the entity whose body starts at `offset` (just after `&`), returning the
    /// decoded bytes and the length consumed including the `;`.
    static func decode(_ input: [UInt8], _ offset: Int) -> ([UInt8], Int)? {
        let size = input.count - offset
        guard size >= 3 else { return nil }
        if input[offset] == UInt8(ascii: "#") {
            return decodeNumeric(input, offset, size: size)
        }
        var index = 2
        while index < min(size, 32) {
            let byte = input[offset + index]
            if byte == MarkdownScan.space { break }
            if byte == UInt8(ascii: ";") {
                let name = String(decoding: input[offset..<offset + index], as: UTF8.self)
                guard let value = named[name] else { return nil }
                return (Array(value.utf8), index + 1)
            }
            index += 1
        }
        return nil
    }

    private static func decodeNumeric(_ input: [UInt8], _ offset: Int, size: Int) -> ([UInt8], Int)? {
        var codepoint: UInt32 = 0
        var index: Int
        let digits: Int
        let maxDigits: Int
        if MarkdownScan.isDigit(input[offset + 1]) {
            index = 1
            while index < size, MarkdownScan.isDigit(input[offset + index]) {
                codepoint = min(codepoint * 10 + UInt32(input[offset + index] - 0x30), 0x110000)
                index += 1
            }
            digits = index - 1
            maxDigits = 7
        } else if input[offset + 1] | 0x20 == UInt8(ascii: "x") {
            index = 2
            while index < size, let value = hexValue(input[offset + index]) {
                codepoint = min(codepoint * 16 + value, 0x110000)
                index += 1
            }
            digits = index - 2
            maxDigits = 6
        } else {
            return nil
        }
        guard (1...maxDigits).contains(digits), index < size, input[offset + index] == UInt8(ascii: ";") else {
            return nil
        }
        let scalar = Unicode.Scalar(codepoint).flatMap { codepoint == 0 ? nil : $0 } ?? "\u{FFFD}"
        return (Array(String(Character(scalar)).utf8), index + 1)
    }

    private static func hexValue(_ byte: UInt8) -> UInt32? {
        switch byte {
        case 0x30...0x39: UInt32(byte - 0x30)
        case 0x41...0x46: UInt32(byte - 0x41 + 10)
        case 0x61...0x66: UInt32(byte - 0x61 + 10)
        default: nil
        }
    }

    /// `houdini_unescape_html_f`: decodes every entity, leaving unknown ones literal.
    static func unescapeHTML(_ bytes: [UInt8]) -> [UInt8] {
        guard bytes.contains(UInt8(ascii: "&")) else { return bytes }
        var result = [UInt8]()
        var index = 0
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "&"), let (decoded, length) = decode(bytes, index + 1) {
                result += decoded
                index += 1 + length
            } else {
                result.append(bytes[index])
                index += 1
            }
        }
        return result
    }
}
