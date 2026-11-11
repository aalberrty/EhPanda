import EhModels
import Foundation

/// Legacy's `MarkdownUtil`: the text, image and link inlines directly inside the top-level
/// paragraphs of a Markdown string, parsed as cmark 0.30.2 (legacy's SwiftCommonMark) did.
enum TagMarkdown {
    static func inlines(_ markdown: String) -> [MarkdownInline] {
        MarkdownBlockParser.paragraphs(of: Array(markdown.utf8)).flatMap(MarkdownInlineParser.parse)
    }

    /// `MarkdownUtil.parseTexts`.
    static func texts(_ markdown: String) -> [String] {
        inlines(markdown).compactMap {
            if case .text(let text) = $0 { text } else { nil }
        }
    }

    /// `MarkdownUtil.parseLinks`.
    static func links(_ markdown: String) -> [URL] {
        inlines(markdown).compactMap {
            if case .link(let url) = $0 { URL(string: url) } else { nil }
        }
    }

    /// `MarkdownUtil.parseImages`: the image URL if it is a valid link, otherwise the title if
    /// that is one (the database hides some URLs as `![alt](# "https://…")`).
    static func images(_ markdown: String) -> [URL] {
        images(in: inlines(markdown))
    }

    static func images(in inlines: [MarkdownInline]) -> [URL] {
        inlines.compactMap { inline in
            guard case .image(let urlString, let title) = inline else { return nil }
            if let url = URL(string: urlString), url.absoluteString.isValidURL { return url }
            if !title.isEmpty, title.isValidURL { return URL(string: title) }
            return nil
        }
    }

    /// Legacy `displayValue` (`valuePlainText ?? value`) and `valueImageURL` of a tag value.
    static func display(of value: String) -> (text: String, imageURL: URL?) {
        if let text = plainParagraphText(value) { return (text, nil) }
        let inlines = inlines(value)
        let text = inlines.lazy.compactMap { if case .text(let text) = $0 { text } else { nil } }.first
        return (text ?? value, images(in: inlines).first)
    }

    /// The paragraph text of a one-line value that cannot contain any Markdown construct, or
    /// `nil` when the full parser is needed. Most database values take this path.
    static func plainParagraphText(_ value: String) -> String? {
        var start: String.UTF8View.Index?
        var end = value.utf8.startIndex
        for index in value.utf8.indices {
            let byte = value.utf8[index]
            switch byte {
            // Inline specials, line ends, tabs and NUL.
            case 0x0A, 0x0D, 0x5C, 0x60, 0x26, 0x5F, 0x2A, 0x5B, 0x5D, 0x3C, 0x21, 0x09, 0x00:
                return nil
            case 0x20, 0x0B, 0x0C:
                continue
            default:
                if start == nil {
                    // Characters that may open a block (quote, heading, list, rule, fence) or
                    // leading indentation that makes a code block.
                    guard value.utf8.distance(from: value.utf8.startIndex, to: index) < 4,
                          !"#>-+=~0123456789".utf8.contains(byte), byte != 0x0B, byte != 0x0C
                    else { return nil }
                    start = index
                }
                end = value.utf8.index(after: index)
            }
        }
        guard let start else { return value.isEmpty ? "" : nil }
        // Leading vertical tabs or form feeds are not indentation to cmark; leave those to the parser.
        guard value.utf8[value.utf8.startIndex..<start].allSatisfy({ $0 == 0x20 }) else { return nil }
        return String(value[start..<end])
    }
}

