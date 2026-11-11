import Foundation

/// Ports cmark 0.30.2's block parser (`blocks.c`) far enough to find the document's top-level
/// paragraphs, the only blocks legacy read. Containers (quotes, lists), code, HTML blocks and
/// headings are tracked only so that their lines, lazy continuations included, are excluded.
/// Link reference definitions are not parsed.
struct MarkdownBlockParser {
    final class Block {
        enum Kind { case document, blockQuote, list, item, codeBlock, htmlBlock, paragraph, heading, thematicBreak }

        var kind: Kind
        weak var parent: Block?
        var children = [Block]()
        var isOpen = true
        var content = [UInt8]()
        var list = ListData()
        var fenceCharacter: UInt8 = 0
        var fenceLength = 0
        var fenceOffset = 0
        var htmlType = 0

        init(_ kind: Kind) { self.kind = kind }
    }

    struct ListData {
        var isOrdered = false
        var bulletCharacter: UInt8 = 0
        var delimiter: UInt8 = 0
        var markerOffset = 0
        var padding = 0
    }

    private let root = Block(.document)
    private var current: Block
    private var line = [UInt8]()
    private var offset = 0
    private var column = 0
    private var firstNonspace = 0
    private var firstNonspaceColumn = 0
    private var indent = 0
    private var isBlank = false

    private init() { current = root }

    /// The raw contents of the top-level paragraphs of `markdown`, in order.
    static func paragraphs(of markdown: [UInt8]) -> [[UInt8]] {
        var parser = MarkdownBlockParser()
        var start = 0
        var index = 0
        while index < markdown.count {
            let byte = markdown[index]
            if byte == MarkdownScan.newline || byte == MarkdownScan.carriageReturn {
                parser.process(line: markdown[start..<index])
                if byte == MarkdownScan.carriageReturn, index + 1 < markdown.count,
                   markdown[index + 1] == MarkdownScan.newline {
                    index += 1
                }
                start = index + 1
            }
            index += 1
        }
        if start < markdown.count { parser.process(line: markdown[start...]) }
        while parser.current !== parser.root, let parent = parser.finalize(parser.current) {
            parser.current = parent
        }
        return parser.root.children.filter { $0.kind == .paragraph }.map(\.content)
    }

    private func byte(_ index: Int) -> UInt8? { index < line.count ? line[index] : nil }

    private mutating func process(line rawLine: ArraySlice<UInt8>) {
        line = rawLine.contains(0) ? rawLine.flatMap { $0 == 0 ? [0xEF, 0xBF, 0xBD] : [$0] } : Array(rawLine)
        line.append(MarkdownScan.newline)
        offset = 0
        column = 0
        firstNonspace = 0
        firstNonspaceColumn = 0
        indent = 0
        isBlank = false
        guard let (lastMatched, allMatched) = checkOpenBlocks() else { return }
        var container = lastMatched
        openNewBlocks(&container, allMatched: allMatched)
        addText(to: container, lastMatched: lastMatched)
    }

    // MARK: Line position

    private mutating func findFirstNonspace() {
        var charsToTab = 4 - column % 4
        if firstNonspace <= offset {
            firstNonspace = offset
            firstNonspaceColumn = column
            while let byte = byte(firstNonspace) {
                if byte == MarkdownScan.space {
                    firstNonspace += 1
                    firstNonspaceColumn += 1
                    charsToTab -= 1
                    if charsToTab == 0 { charsToTab = 4 }
                } else if byte == MarkdownScan.tab {
                    firstNonspace += 1
                    firstNonspaceColumn += charsToTab
                    charsToTab = 4
                } else {
                    break
                }
            }
        }
        indent = firstNonspaceColumn - column
        isBlank = MarkdownScan.isLineEnd(byte(firstNonspace))
    }

    private mutating func advance(_ count: Int, columns: Bool) {
        var count = count
        while count > 0, let byte = byte(offset) {
            if byte == MarkdownScan.tab {
                let charsToTab = 4 - column % 4
                if columns {
                    let partiallyConsumed = charsToTab > count
                    let advance = min(count, charsToTab)
                    column += advance
                    offset += partiallyConsumed ? 0 : 1
                    count -= advance
                } else {
                    column += charsToTab
                    offset += 1
                    count -= 1
                }
            } else {
                offset += 1
                column += 1
                count -= 1
            }
        }
    }

    // MARK: Phase 1

    private mutating func checkOpenBlocks() -> (Block, Bool)? {
        var container = root
        var allMatched = true
        var shouldContinue = true
        matching: while let last = container.children.last, last.isOpen {
            container = last
            findFirstNonspace()
            let matched: Bool
            switch container.kind {
            case .blockQuote: matched = parseBlockQuotePrefix()
            case .item: matched = parseItemPrefix(container)
            case .codeBlock: matched = parseCodeBlockPrefix(container, shouldContinue: &shouldContinue)
            case .heading: matched = false
            case .htmlBlock: matched = container.htmlType <= 5 || !isBlank
            case .paragraph: matched = !isBlank
            default: matched = true
            }
            if !matched {
                allMatched = false
                container = container.parent ?? root
                break matching
            }
        }
        return shouldContinue ? (container, allMatched) : nil
    }

    private mutating func parseBlockQuotePrefix() -> Bool {
        guard indent <= 3, byte(firstNonspace) == UInt8(ascii: ">") else { return false }
        advance(indent + 1, columns: true)
        if MarkdownScan.isSpaceOrTab(byte(offset)) { advance(1, columns: true) }
        return true
    }

    private mutating func parseItemPrefix(_ item: Block) -> Bool {
        if indent >= item.list.markerOffset + item.list.padding {
            advance(item.list.markerOffset + item.list.padding, columns: true)
            return true
        }
        if isBlank, !item.children.isEmpty {
            advance(firstNonspace - offset, columns: false)
            return true
        }
        return false
    }

    private mutating func parseCodeBlockPrefix(_ code: Block, shouldContinue: inout Bool) -> Bool {
        guard code.fenceCharacter != 0 else {
            if indent >= 4 {
                advance(4, columns: true)
                return true
            }
            if isBlank {
                advance(firstNonspace - offset, columns: false)
                return true
            }
            return false
        }
        let closing = indent <= 3 && byte(firstNonspace) == code.fenceCharacter
            ? MarkdownBlockScan.closingFence(line, firstNonspace) : 0
        if closing >= code.fenceLength {
            shouldContinue = false
            advance(closing, columns: false)
            current = finalize(code) ?? root
            return false
        }
        var remaining = code.fenceOffset
        while remaining > 0, MarkdownScan.isSpaceOrTab(byte(offset)) {
            advance(1, columns: true)
            remaining -= 1
        }
        return true
    }

    // MARK: Phase 2

    private mutating func openNewBlocks(_ container: inout Block, allMatched: Bool) {
        var maybeLazy = current.kind == .paragraph
        var containerKind = container.kind
        while containerKind != .codeBlock, containerKind != .htmlBlock {
            findFirstNonspace()
            let indented = indent >= 4
            if !indented, byte(firstNonspace) == UInt8(ascii: ">") {
                advance(firstNonspace + 1 - offset, columns: false)
                if MarkdownScan.isSpaceOrTab(byte(offset)) { advance(1, columns: true) }
                container = addChild(to: container, .blockQuote)
            } else if !indented, case let length = MarkdownBlockScan.atxHeadingStart(line, firstNonspace), length > 0 {
                advance(firstNonspace + length - offset, columns: false)
                container = addChild(to: container, .heading)
            } else if !indented, case let length = MarkdownBlockScan.openingFence(line, firstNonspace), length > 0 {
                let fenceCharacter = line[firstNonspace]
                let fenceOffset = firstNonspace - offset
                container = addChild(to: container, .codeBlock)
                container.fenceCharacter = fenceCharacter
                container.fenceLength = min(length, 255)
                container.fenceOffset = fenceOffset
                advance(firstNonspace + length - offset, columns: false)
            } else if !indented, case let type = MarkdownHTML.blockStart(
                line, firstNonspace, allowsType7: containerKind != .paragraph && !maybeLazy
            ), type > 0 {
                container = addChild(to: container, .htmlBlock)
                container.htmlType = type
            } else if !indented, containerKind == .paragraph, MarkdownBlockScan.isSetextUnderline(line, firstNonspace) {
                container.kind = .heading
                advance(line.count - 1 - offset, columns: false)
            } else if !indented, !(containerKind == .paragraph && !allMatched),
                      MarkdownBlockScan.isThematicBreak(line, firstNonspace) {
                container = addChild(to: container, .thematicBreak)
                advance(line.count - 1 - offset, columns: false)
            } else if indent < 4, let (length, marker) = MarkdownBlockScan.listMarker(
                line, firstNonspace, interruptsParagraph: container.kind == .paragraph
            ) {
                openListItem(&container, containerKind: containerKind, markerLength: length, marker: marker)
            } else if indented, !maybeLazy, !isBlank {
                advance(4, columns: true)
                container = addChild(to: container, .codeBlock)
            } else {
                break
            }
            if container.kind == .paragraph || container.kind == .heading { break }
            containerKind = container.kind
            maybeLazy = false
        }
    }

    private mutating func openListItem(
        _ container: inout Block, containerKind: Block.Kind, markerLength: Int, marker: ListData
    ) {
        var data = marker
        advance(firstNonspace + markerLength - offset, columns: false)
        let savedOffset = offset
        let savedColumn = column
        while column - savedColumn <= 5, MarkdownScan.isSpaceOrTab(byte(offset)) {
            advance(1, columns: true)
        }
        let spaces = column - savedColumn
        if spaces >= 5 || spaces < 1 || MarkdownScan.isLineEnd(byte(offset)) {
            data.padding = markerLength + 1
            offset = savedOffset
            column = savedColumn
            if spaces > 0 { advance(1, columns: true) }
        } else {
            data.padding = markerLength + spaces
        }
        data.markerOffset = indent
        let matchesList = containerKind == .list && container.list.isOrdered == data.isOrdered
            && container.list.delimiter == data.delimiter && container.list.bulletCharacter == data.bulletCharacter
        if !matchesList {
            container = addChild(to: container, .list)
            container.list = data
        }
        container = addChild(to: container, .item)
        container.list = data
    }

    // MARK: Phase 3

    private mutating func addText(to container: Block, lastMatched: Block) {
        var container = container
        findFirstNonspace()
        if current !== lastMatched, container === lastMatched, !isBlank, current.kind == .paragraph {
            current.content += line[offset...]
            return
        }
        while current !== lastMatched, let parent = finalize(current) { current = parent }
        switch container.kind {
        case .codeBlock:
            break
        case .htmlBlock:
            if container.htmlType <= 5, MarkdownHTML.blockEnds(line, firstNonspace, type: container.htmlType) {
                container = finalize(container) ?? root
            }
        default:
            guard !isBlank else { break }
            if container.kind != .paragraph, container.kind != .heading {
                container = addChild(to: container, .paragraph)
            }
            advance(firstNonspace - offset, columns: false)
            container.content += line[offset...]
        }
        current = container
    }

    private mutating func addChild(to parent: Block, _ kind: Block.Kind) -> Block {
        var parent = parent
        while !(parent.kind == .document || parent.kind == .blockQuote || parent.kind == .item
            || (parent.kind == .list && kind == .item)) {
            parent = finalize(parent) ?? root
        }
        let child = Block(kind)
        child.parent = parent
        parent.children.append(child)
        return child
    }

    private func finalize(_ block: Block) -> Block? {
        block.isOpen = false
        return block.parent
    }
}
