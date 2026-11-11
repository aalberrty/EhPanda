import Foundation

/// A top-level inline of a Markdown paragraph, as legacy's SwiftCommonMark exposed it.
/// Children of emphasis, links and images are not kept: legacy never read them.
enum MarkdownInline: Equatable {
    /// Adjacent text nodes merged, as cmark's `cmark_consolidate_text_nodes` does.
    case text(String)
    /// `url` and `title` as cmark stored them (entities and escapes decoded).
    case image(url: String, title: String)
    case link(url: String)
    /// Code spans, emphasis, inline HTML and line breaks.
    case other
}

/// Ports cmark 0.30.2's inline parser (`inlines.c`, no smart punctuation, no reference
/// definitions) far enough to know which nodes end up directly in the paragraph.
struct MarkdownInlineParser {
    final class Node {
        enum Kind { case text, image, link, other }
        var kind: Kind
        var bytes: [UInt8]
        var url = ""
        var title = ""

        init(_ kind: Kind, _ bytes: [UInt8] = []) {
            self.kind = kind
            self.bytes = bytes
        }
    }

    final class Delimiter {
        let character: UInt8
        let canOpen: Bool
        let canClose: Bool
        let node: Node
        let position: Int
        let length: Int
        var previous: Delimiter?
        var next: Delimiter?

        init(character: UInt8, canOpen: Bool, canClose: Bool, node: Node, position: Int) {
            self.character = character
            self.canOpen = canOpen
            self.canClose = canClose
            self.node = node
            self.position = position
            self.length = node.bytes.count
        }
    }

    final class Bracket {
        let isImage: Bool
        var isActive = true
        let node: Node
        let position: Int
        let previous: Bracket?

        init(isImage: Bool, node: Node, position: Int, previous: Bracket?) {
            self.isImage = isImage
            self.node = node
            self.position = position
            self.previous = previous
        }
    }

    let input: [UInt8]
    var position = 0
    var nodes = [Node]()
    var lastDelimiter: Delimiter?
    var lastBracket: Bracket?

    /// Parses one paragraph's raw content.
    static func parse(_ content: [UInt8]) -> [MarkdownInline] {
        var end = content.count
        while end > 0, MarkdownScan.isSpace(content[end - 1]) { end -= 1 }
        var parser = MarkdownInlineParser(input: Array(content[..<end]))
        while parser.position < parser.input.count { parser.parseInline() }
        parser.processEmphasis(stackBottom: 0)
        return parser.consolidated()
    }

    private func peek(_ offset: Int = 0) -> UInt8? {
        position + offset < input.count ? input[position + offset] : nil
    }

    private mutating func appendText(_ bytes: [UInt8]) -> Node {
        let node = Node(.text, bytes)
        nodes.append(node)
        return node
    }

    private mutating func parseInline() {
        guard let byte = peek() else { return }
        switch byte {
        case MarkdownScan.newline, MarkdownScan.carriageReturn: handleNewline()
        case UInt8(ascii: "`"): handleBackticks()
        case UInt8(ascii: "\\"): handleBackslash()
        case UInt8(ascii: "&"): handleEntity()
        case UInt8(ascii: "<"): handlePointyBrace()
        case UInt8(ascii: "*"), UInt8(ascii: "_"): handleDelimiter(byte)
        case UInt8(ascii: "["):
            position += 1
            pushBracket(isImage: false, node: appendText([byte]))
        case UInt8(ascii: "]"): handleCloseBracket()
        case UInt8(ascii: "!"):
            position += 1
            if peek() == UInt8(ascii: "[") {
                position += 1
                pushBracket(isImage: true, node: appendText(Array("![".utf8)))
            } else {
                _ = appendText([byte])
            }
        default:
            let start = position
            position += 1
            while let next = peek(), !Self.isSpecial(next) { position += 1 }
            var end = position
            if MarkdownScan.isLineEnd(peek()) {
                while end > start, MarkdownScan.isSpace(input[end - 1]) { end -= 1 }
            }
            _ = appendText(Array(input[start..<end]))
        }
    }

    /// `\r \n \\ ` & _ * [ ] < !`.
    private static func isSpecial(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x0A, 0x0D, 0x5C, 0x60, 0x26, 0x5F, 0x2A, 0x5B, 0x5D, 0x3C, 0x21: true
        default: false
        }
    }

    private mutating func handleNewline() {
        let newlinePosition = position
        if peek() == MarkdownScan.carriageReturn { position += 1 }
        if peek() == MarkdownScan.newline { position += 1 }
        while MarkdownScan.isSpaceOrTab(peek()) { position += 1 }
        _ = newlinePosition
        nodes.append(Node(.other))
    }

    private mutating func handleBackticks() {
        let start = position
        while peek() == UInt8(ascii: "`") { position += 1 }
        let openLength = position - start
        let afterOpen = position
        while position < input.count {
            while let byte = peek(), byte != UInt8(ascii: "`") { position += 1 }
            let runStart = position
            while peek() == UInt8(ascii: "`") { position += 1 }
            if position - runStart == openLength {
                nodes.append(Node(.other))
                return
            }
        }
        position = afterOpen
        _ = appendText(Array(input[start..<afterOpen]))
    }

    private mutating func handleBackslash() {
        position += 1
        if let next = peek(), MarkdownScan.isASCIIPunctuation(next) {
            position += 1
            _ = appendText([next])
        } else if position < input.count, MarkdownScan.isLineEnd(peek()) {
            if peek() == MarkdownScan.carriageReturn { position += 1 }
            if peek() == MarkdownScan.newline { position += 1 }
            nodes.append(Node(.other))
        } else {
            _ = appendText([UInt8(ascii: "\\")])
        }
    }

    private mutating func handleEntity() {
        position += 1
        if let (decoded, length) = MarkdownEntities.decode(input, position) {
            position += length
            _ = appendText(decoded)
        } else {
            _ = appendText([UInt8(ascii: "&")])
        }
    }

    private mutating func handlePointyBrace() {
        position += 1
        var length = MarkdownScan.autolinkURI(input, position)
        if length > 0 {
            appendAutolink(Array(input[position..<position + length - 1]), isEmail: false)
            position += length
            return
        }
        length = MarkdownScan.autolinkEmail(input, position)
        if length > 0 {
            appendAutolink(Array(input[position..<position + length - 1]), isEmail: true)
            position += length
            return
        }
        length = MarkdownHTML.inlineLength(input, position)
        if length > 0 {
            position += length
            nodes.append(Node(.other))
        } else {
            _ = appendText([UInt8(ascii: "<")])
        }
    }

    private mutating func appendAutolink(_ contents: [UInt8], isEmail: Bool) {
        let node = Node(.link)
        let url = MarkdownEntities.unescapeHTML(MarkdownInlineParser.trimmed(contents))
        node.url = (isEmail ? "mailto:" : "") + String(decoding: url, as: UTF8.self)
        nodes.append(node)
    }

    private mutating func handleDelimiter(_ character: UInt8) {
        let beforeChar = position == 0 ? 10 : Self.scalar(endingBefore: position, in: input)
        let start = position
        while peek() == character { position += 1 }
        let afterChar = position < input.count ? Self.scalar(startingAt: position, in: input) : 10
        let leftFlanking = !MarkdownScan.isUnicodeSpace(afterChar)
            && (!MarkdownScan.isUnicodePunctuation(afterChar) || MarkdownScan.isUnicodeSpace(beforeChar)
                || MarkdownScan.isUnicodePunctuation(beforeChar))
        let rightFlanking = !MarkdownScan.isUnicodeSpace(beforeChar)
            && (!MarkdownScan.isUnicodePunctuation(beforeChar) || MarkdownScan.isUnicodeSpace(afterChar)
                || MarkdownScan.isUnicodePunctuation(afterChar))
        let canOpen: Bool
        let canClose: Bool
        if character == UInt8(ascii: "_") {
            canOpen = leftFlanking && (!rightFlanking || MarkdownScan.isUnicodePunctuation(beforeChar))
            canClose = rightFlanking && (!leftFlanking || MarkdownScan.isUnicodePunctuation(afterChar))
        } else {
            canOpen = leftFlanking
            canClose = rightFlanking
        }
        let node = appendText(Array(input[start..<position]))
        guard canOpen || canClose else { return }
        let delimiter = Delimiter(
            character: character, canOpen: canOpen, canClose: canClose, node: node, position: position
        )
        delimiter.previous = lastDelimiter
        lastDelimiter?.next = delimiter
        lastDelimiter = delimiter
    }

    private mutating func pushBracket(isImage: Bool, node: Node) {
        lastBracket = Bracket(isImage: isImage, node: node, position: position, previous: lastBracket)
    }

    private mutating func handleCloseBracket() {
        position += 1
        let initialPosition = position
        guard let opener = lastBracket else {
            _ = appendText([UInt8(ascii: "]")])
            return
        }
        guard opener.isActive, let (url, title) = scanInlineLink() else {
            // No reference definitions are parsed, so only inline links can match.
            lastBracket = opener.previous
            position = initialPosition
            _ = appendText([UInt8(ascii: "]")])
            return
        }
        let link = Node(opener.isImage ? .image : .link)
        link.url = url
        link.title = title
        if let index = nodes.lastIndex(where: { $0 === opener.node }) {
            nodes.replaceSubrange(index..., with: [link])
        }
        // Emphasis inside the link text belongs to the link; drop its delimiters.
        while let delimiter = lastDelimiter, delimiter.position >= opener.position {
            removeDelimiter(delimiter)
        }
        lastBracket = opener.previous
        if !opener.isImage {
            var bracket = lastBracket
            while let current = bracket {
                if !current.isImage {
                    if !current.isActive { break }
                    current.isActive = false
                }
                bracket = current.previous
            }
        }
    }

    /// `(destination "title")` after a `]`, advancing past it on success.
    private mutating func scanInlineLink() -> (url: String, title: String)? {
        guard peek() == UInt8(ascii: "(") else { return nil }
        let urlStart = position + 1 + MarkdownScan.spaceChars(input, position + 1)
        guard let (urlRange, urlLength) = MarkdownLinkDestination.scan(input, urlStart) else { return nil }
        let urlEnd = urlStart + urlLength
        let titleStart = urlEnd + MarkdownScan.spaceChars(input, urlEnd)
        let titleEnd = titleStart == urlEnd ? titleStart : titleStart + MarkdownScan.linkTitle(input, titleStart)
        let end = titleEnd + MarkdownScan.spaceChars(input, titleEnd)
        guard end < input.count, input[end] == UInt8(ascii: ")") else { return nil }
        position = end + 1
        let url = MarkdownLinkDestination.clean(Array(input[urlRange]))
        let title = MarkdownLinkDestination.cleanTitle(Array(input[titleStart..<titleEnd]))
        return (String(decoding: url, as: UTF8.self), String(decoding: title, as: UTF8.self))
    }

    static func trimmed(_ bytes: [UInt8]) -> [UInt8] {
        var start = 0
        var end = bytes.count
        while start < end, MarkdownScan.isSpace(bytes[start]) { start += 1 }
        while end > start, MarkdownScan.isSpace(bytes[end - 1]) { end -= 1 }
        return Array(bytes[start..<end])
    }

    private func consolidated() -> [MarkdownInline] {
        var result = [MarkdownInline]()
        var pendingText: [UInt8]?
        func flush() {
            if let text = pendingText { result.append(.text(String(decoding: text, as: UTF8.self))) }
            pendingText = nil
        }
        for node in nodes {
            switch node.kind {
            case .text:
                pendingText = (pendingText ?? []) + node.bytes
            case .image:
                flush()
                result.append(.image(url: node.url, title: node.title))
            case .link:
                flush()
                result.append(.link(url: node.url))
            case .other:
                flush()
                result.append(.other)
            }
        }
        flush()
        return result
    }
}

// MARK: UTF-8 neighbours

extension MarkdownInlineParser {
    /// The scalar ending right before `index`, or a newline if it cannot be decoded.
    static func scalar(endingBefore index: Int, in input: [UInt8]) -> UInt32 {
        var start = index - 1
        while start > 0, input[start] >> 6 == 2 { start -= 1 }
        return decodedScalar(input, start, limit: index) ?? 10
    }

    static func scalar(startingAt index: Int, in input: [UInt8]) -> UInt32 {
        decodedScalar(input, index, limit: input.count) ?? 10
    }

    private static func decodedScalar(_ input: [UInt8], _ start: Int, limit: Int) -> UInt32? {
        var iterator = input[start..<limit].makeIterator()
        var decoder = UTF8()
        if case .scalarValue(let scalar) = decoder.decode(&iterator) { return scalar.value }
        return nil
    }
}
