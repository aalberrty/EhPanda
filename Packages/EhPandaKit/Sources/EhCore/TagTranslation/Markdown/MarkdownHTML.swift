import Foundation

/// Raw HTML recognition, inline and block, from cmark 0.30.2.
enum MarkdownHTML {
    /// The bytes after `<` that form inline HTML (`handle_pointy_brace`), `0` if none.
    static func inlineLength(_ input: [UInt8], _ offset: Int) -> Int {
        guard offset + 2 <= input.count else { return 0 }
        var length = 0
        switch input[offset] {
        case UInt8(ascii: "!"):
            switch input[offset + 1] {
            case UInt8(ascii: "-"):
                length = comment(input, offset + 2)
                if length > 0 { length += 2 }
            case UInt8(ascii: "["):
                length = cdata(input, offset + 2)
                if length > 0 { length += 5 }
            default:
                length = declaration(input, offset + 1)
                if length > 0 { length += 2 }
            }
        case UInt8(ascii: "?"):
            length = processingInstruction(input, offset + 1) + 3
        default:
            return MarkdownScan.htmlTag(input, offset)
        }
        return offset + length > input.count ? 0 : length
    }

    /// `"--->" | ("-" ([-]? [^\x00>-]) ([-]? [^\x00-])* "-->")`.
    private static func comment(_ input: [UInt8], _ offset: Int) -> Int {
        if MarkdownScan.hasPrefix(input, offset, "--->") { return 4 }
        let dash = UInt8(ascii: "-")
        guard offset < input.count, input[offset] == dash else { return 0 }
        var index = offset + 1
        if index < input.count, input[index] == dash { index += 1 }
        guard index < input.count, input[index] != 0, input[index] != UInt8(ascii: ">"), input[index] != dash else {
            return 0
        }
        index += 1
        // The body may not contain "--"; the first one must start the closing "-->".
        while index < input.count, input[index] != 0 {
            if input[index] == dash, index + 1 < input.count, input[index + 1] == dash {
                return MarkdownScan.hasPrefix(input, index, "-->") ? index + 3 - offset : 0
            }
            index += 1
        }
        return 0
    }

    /// `([^?>\x00]+ | [?][^>\x00] | [>])+`, which stops before `?>`.
    private static func processingInstruction(_ input: [UInt8], _ offset: Int) -> Int {
        var index = offset
        while index < input.count, input[index] != 0 {
            if input[index] == UInt8(ascii: "?") {
                guard index + 1 < input.count, input[index + 1] != UInt8(ascii: ">"), input[index + 1] != 0 else {
                    break
                }
                index += 2
            } else {
                index += 1
            }
        }
        return index - offset
    }

    /// `[A-Z]+ spacechar+ [^>\x00]*`.
    private static func declaration(_ input: [UInt8], _ offset: Int) -> Int {
        var index = offset
        while index < input.count, (0x41...0x5A).contains(input[index]) { index += 1 }
        guard index > offset else { return 0 }
        let spaces = MarkdownScan.spaceChars(input, index)
        guard spaces > 0 else { return 0 }
        index += spaces
        while index < input.count, input[index] != UInt8(ascii: ">"), input[index] != 0 { index += 1 }
        return index - offset
    }

    /// `"CDATA[" ([^\]\x00]+ | "]" [^\]\x00] | "]]" [^>\x00])*`.
    private static func cdata(_ input: [UInt8], _ offset: Int) -> Int {
        guard MarkdownScan.hasPrefix(input, offset, "CDATA[") else { return 0 }
        let bracket = UInt8(ascii: "]")
        var index = offset + 6
        while index < input.count, input[index] != 0 {
            if input[index] != bracket {
                index += 1
            } else if index + 1 < input.count, input[index + 1] != bracket, input[index + 1] != 0 {
                index += 2
            } else if index + 2 < input.count, input[index + 1] == bracket,
                      input[index + 2] != UInt8(ascii: ">"), input[index + 2] != 0 {
                index += 3
            } else {
                break
            }
        }
        return index - offset
    }

    // MARK: Blocks

    private static let blockTagNames: Set<String> = [
        "address", "article", "aside", "base", "basefont", "blockquote", "body", "caption", "center", "col",
        "colgroup", "dd", "details", "dialog", "dir", "div", "dl", "dt", "fieldset", "figcaption", "figure",
        "footer", "form", "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hr",
        "html", "iframe", "legend", "li", "link", "main", "menu", "menuitem", "nav", "noframes", "ol",
        "optgroup", "option", "p", "param", "section", "source", "title", "summary", "table", "tbody", "td",
        "tfoot", "th", "thead", "tr", "track", "ul"
    ]

    /// `scan_html_block_start`, and type 7 when `allowsType7`. `line` ends with a newline.
    static func blockStart(_ line: [UInt8], _ offset: Int, allowsType7: Bool) -> Int {
        guard offset < line.count, line[offset] == UInt8(ascii: "<") else { return 0 }
        for name in ["script", "pre", "textarea", "style"]
        where MarkdownScan.hasPrefix(line, offset + 1, name, caseInsensitive: true) {
            let next = offset + 1 + name.utf8.count
            if next < line.count, MarkdownScan.isSpace(line[next]) || line[next] == UInt8(ascii: ">") { return 1 }
        }
        if MarkdownScan.hasPrefix(line, offset, "<!--") { return 2 }
        if MarkdownScan.hasPrefix(line, offset, "<?") { return 3 }
        if MarkdownScan.hasPrefix(line, offset, "<!"), offset + 2 < line.count,
           (0x41...0x5A).contains(line[offset + 2]) {
            return 4
        }
        if MarkdownScan.hasPrefix(line, offset, "<![CDATA[") { return 5 }
        if isBlockTag(line, offset + 1) { return 6 }
        if allowsType7, isType7(line, offset + 1) { return 7 }
        return 0
    }

    /// `[/]? blocktagname (spacechar | [/]? [>])`, case-insensitively.
    private static func isBlockTag(_ line: [UInt8], _ offset: Int) -> Bool {
        var start = offset
        if start < line.count, line[start] == UInt8(ascii: "/") { start += 1 }
        var end = start
        while end < line.count, MarkdownScan.isAlphanumeric(line[end]) { end += 1 }
        var length = end - start
        while length > 0 {
            let name = String(decoding: line[start..<start + length], as: UTF8.self).lowercased()
            if blockTagNames.contains(name) {
                var next = start + length
                if next < line.count, MarkdownScan.isSpace(line[next]) { return true }
                if next < line.count, line[next] == UInt8(ascii: "/") { next += 1 }
                if next < line.count, line[next] == UInt8(ascii: ">") { return true }
            }
            length -= 1
        }
        return false
    }

    /// `[<] (opentag | closetag) [\t\n\f ]* [\r\n]`.
    private static func isType7(_ line: [UInt8], _ offset: Int) -> Bool {
        let length = MarkdownScan.htmlTag(line, offset)
        guard length > 0 else { return false }
        var index = offset + length
        while index < line.count, [0x09, 0x0C, 0x20].contains(line[index]) { index += 1 }
        return index < line.count && MarkdownScan.isLineEnd(line[index])
    }

    /// Whether `line` from `offset` contains the end marker of an HTML block of `type` (1–5).
    static func blockEnds(_ line: [UInt8], _ offset: Int, type: Int) -> Bool {
        switch type {
        case 1:
            ["</script>", "</pre>", "</textarea>", "</style>"].contains { tag in
                var index = offset
                while index < line.count, line[index] != MarkdownScan.newline {
                    if MarkdownScan.hasPrefix(line, index, tag, caseInsensitive: true) { return true }
                    index += 1
                }
                return false
            }
        case 2: MarkdownScan.lineContains(line, offset, "-->")
        case 3: MarkdownScan.lineContains(line, offset, "?>")
        case 4: MarkdownScan.lineContains(line, offset, ">")
        case 5: MarkdownScan.lineContains(line, offset, "]]>")
        default: false
        }
    }
}
