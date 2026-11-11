import Foundation

/// Block-start scanners from cmark 0.30.2. Each `line` ends with a newline.
enum MarkdownBlockScan {
    private static let backtick = UInt8(ascii: "`")
    private static let tilde = UInt8(ascii: "~")

    /// `[#]{1,6} ([ \t]+ | [\r\n])`.
    static func atxHeadingStart(_ line: [UInt8], _ offset: Int) -> Int {
        var index = offset
        while index < line.count, line[index] == UInt8(ascii: "#"), index - offset < 6 { index += 1 }
        guard index > offset, index < line.count else { return 0 }
        if MarkdownScan.isLineEnd(line[index]) { return index + 1 - offset }
        guard MarkdownScan.isSpaceOrTab(line[index]) else { return 0 }
        while index < line.count, MarkdownScan.isSpaceOrTab(line[index]) { index += 1 }
        return index - offset
    }

    /// `[=]+ [ \t]* [\r\n]` or `[-]+ [ \t]* [\r\n]`.
    static func isSetextUnderline(_ line: [UInt8], _ offset: Int) -> Bool {
        guard offset < line.count, line[offset] == UInt8(ascii: "=") || line[offset] == UInt8(ascii: "-") else {
            return false
        }
        let character = line[offset]
        var index = offset
        while index < line.count, line[index] == character { index += 1 }
        while index < line.count, MarkdownScan.isSpaceOrTab(line[index]) { index += 1 }
        return index < line.count && MarkdownScan.isLineEnd(line[index])
    }

    /// Three or more `*`, `-` or `_`, optionally separated by spaces or tabs, then the line end.
    static func isThematicBreak(_ line: [UInt8], _ offset: Int) -> Bool {
        guard offset < line.count, "*_-".utf8.contains(line[offset]) else { return false }
        let character = line[offset]
        var count = 0
        var index = offset
        while index < line.count {
            if line[index] == character {
                count += 1
            } else if !MarkdownScan.isSpaceOrTab(line[index]) {
                break
            }
            index += 1
        }
        return count >= 3 && index < line.count && MarkdownScan.isLineEnd(line[index])
    }

    /// Three or more backticks not followed by another backtick on the line, or three or more
    /// tildes. Returns the fence length.
    static func openingFence(_ line: [UInt8], _ offset: Int) -> Int {
        guard offset < line.count, line[offset] == backtick || line[offset] == tilde else { return 0 }
        let character = line[offset]
        var index = offset
        while index < line.count, line[index] == character { index += 1 }
        let length = index - offset
        guard length >= 3 else { return 0 }
        while index < line.count, !MarkdownScan.isLineEnd(line[index]) {
            if character == backtick, line[index] == backtick { return 0 }
            index += 1
        }
        return index < line.count ? length : 0
    }

    /// Three or more fence characters followed only by spaces or tabs. Returns the fence length.
    static func closingFence(_ line: [UInt8], _ offset: Int) -> Int {
        guard offset < line.count, line[offset] == backtick || line[offset] == tilde else { return 0 }
        let character = line[offset]
        var index = offset
        while index < line.count, line[index] == character { index += 1 }
        let length = index - offset
        while index < line.count, MarkdownScan.isSpaceOrTab(line[index]) { index += 1 }
        return length >= 3 && index < line.count && MarkdownScan.isLineEnd(line[index]) ? length : 0
    }

    /// `parse_list_marker`.
    static func listMarker(
        _ line: [UInt8], _ offset: Int, interruptsParagraph: Bool
    ) -> (Int, MarkdownBlockParser.ListData)? {
        guard offset < line.count else { return nil }
        var data = MarkdownBlockParser.ListData()
        var index = offset
        let first = line[index]
        if first == UInt8(ascii: "*") || first == UInt8(ascii: "-") || first == UInt8(ascii: "+") {
            index += 1
            guard index < line.count, MarkdownScan.isSpace(line[index]) else { return nil }
            data.bulletCharacter = first
        } else if MarkdownScan.isDigit(first) {
            var start = 0
            var digits = 0
            repeat {
                start = start * 10 + Int(line[index] - 0x30)
                index += 1
                digits += 1
            } while digits < 9 && index < line.count && MarkdownScan.isDigit(line[index])
            if interruptsParagraph, start != 1 { return nil }
            guard index < line.count, line[index] == UInt8(ascii: ".") || line[index] == UInt8(ascii: ")") else {
                return nil
            }
            data.isOrdered = true
            data.delimiter = line[index]
            index += 1
            guard index < line.count, MarkdownScan.isSpace(line[index]) else { return nil }
        } else {
            return nil
        }
        if interruptsParagraph {
            var contentIndex = index
            while contentIndex < line.count, MarkdownScan.isSpaceOrTab(line[contentIndex]) { contentIndex += 1 }
            if contentIndex < line.count, MarkdownScan.isLineEnd(line[contentIndex]) { return nil }
        }
        return (index - offset, data)
    }
}
