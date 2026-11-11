import EhModels
import Foundation
import Kanna

// MARK: Preview

extension Parser {
    /// Everything a page of a gallery's preview grid lists: each page's thumbnail and the link
    /// to its viewer page. The detail page is the first preview page, so this reads it too.
    public static func parsePreviewPage(doc: HTMLDocument) throws -> PreviewPage {
        PreviewPage(previewURLs: try parsePreviewURLs(doc: doc), pageURLs: try parsePageURLs(doc: doc))
    }

    /// Preview thumbnails on a detail page, keyed by 1-based page index.
    ///
    /// Sprite-sheet previews come back as the sheet URL with the crop encoded in its query
    /// (`CombinedPreviewURL`).
    static func parsePreviewURLs(doc: HTMLDocument) throws -> [Int: URL] {
        guard let gdtNode = doc.at_xpath("//div [@id='gdt']")
        else { throw AppError.parseFailed }

        let combinedURLs = parseCombinedPreviewURLs(node: gdtNode)
        return combinedURLs.isEmpty ? parseStandalonePreviewURLs(node: gdtNode) : combinedURLs
    }

    private static func parseCombinedPreviewURLs(node: Kanna.XMLElement) -> [Int: URL] {
        var previewURLs = [Int: URL]()

        for link in node.xpath("//a") {
            if let divNode = link.at_xpath(".//div[@title and @style]"),
               let style = divNode["style"],
               let rangeA = style.range(of: "width:"),
               let rangeB = style.range(of: "px;height:"),
               let rangeC = style.range(of: "px;background"),
               let rangeD = style.range(of: "url("),
               let rangeE = style.range(of: ") -"),
               let rangeF = style[rangeE.upperBound...].range(of: "px "),
               rangeA.upperBound <= rangeB.lowerBound,
               rangeB.upperBound <= rangeC.lowerBound,
               rangeD.upperBound <= rangeE.lowerBound,
               let urlString = style[rangeD.upperBound..<rangeE.lowerBound]
                   .replacingOccurrences(of: "'", with: "")
                   .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: urlString),
               let title = divNode["title"],
               let index = parseGTX00IndexFromTitle(from: title)
            {
                let width = String(style[rangeA.upperBound..<rangeB.lowerBound])
                let height = String(style[rangeB.upperBound..<rangeC.lowerBound])
                let offset = String(style[rangeE.upperBound..<rangeF.lowerBound])

                previewURLs[index] = CombinedPreviewURL.url(plainURL: url, width: width, height: height, offset: offset)
            }
        }
        return previewURLs
    }

    private static func parseStandalonePreviewURLs(node: Kanna.XMLElement) -> [Int: URL] {
        var previewURLs = [Int: URL]()

        for link in node.xpath("//a") {
            if let divNode = link.at_xpath(".//div[@title and @style]"),
               let style = divNode["style"],
               let rangeA = style.range(of: "url("),
               let rangeB = style.range(of: ")"),
               rangeA.upperBound <= rangeB.lowerBound,
               let urlString = style[rangeA.upperBound..<rangeB.lowerBound]
                   .replacingOccurrences(of: "'", with: "")
                   .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: urlString),
               let title = divNode["title"],
               let index = parseGTX00IndexFromTitle(from: title)
            {
                previewURLs[index] = url
            }
        }
        return previewURLs
    }

    /// `"Page 12: name.jpg"` → `12`.
    public static func parseGTX00IndexFromTitle(from title: String) -> Int? {
        // The probable format of page title is "Page [Number]: filename"
        (
            title
                .components(separatedBy: ":")
                .first?
                .replacingOccurrences(of: "Page ", with: "")
                .trimmingCharacters(in: .whitespaces)
        )
        .flatMap(Int.init)
    }

    /// `"gt100"` (normal) or `"gt200"` (large) previews.
    public static func parsePreviewMode(doc: HTMLDocument) throws -> String {
        if doc.at_xpath("//div [@class='gt100']") != nil {
            return "gt100"
        } else if doc.at_xpath("//div [@class='gt200']") != nil {
            return "gt200"
        } else {
            throw AppError.parseFailed
        }
    }
}

// MARK: Image page

extension Parser {
    /// Links to the viewer pages (`/s/…`, legacy "thumbnail URLs") on a detail page, keyed by
    /// 1-based index.
    static func parsePageURLs(doc: HTMLDocument) throws -> [Int: URL] {
        var pageURLs = [Int: URL]()

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']")
        else { throw AppError.parseFailed }

        for aLink in gdtNode.xpath("a") {
            guard let href = aLink["href"],
                  let pageURL = URL(string: href),
                  let divNode = aLink.at_xpath(".//div[@title and @style]"),
                  let title = divNode["title"],
                  let index = parseGTX00IndexFromTitle(from: title)
            else { continue }

            pageURLs[index] = pageURL
        }

        return pageURLs
    }

    /// The `nl` value of an image page's "Reload broken image" link.
    public static func parseSkipServerIdentifier(doc: HTMLDocument) throws -> String {
        guard let text = doc.at_xpath("//div [@id='i6']")?.at_xpath("//a [@id='loadfail']")?["onclick"],
              let rangeA = text.range(of: "nl('"), let rangeB = text.range(of: "')"),
              rangeA.upperBound <= rangeB.lowerBound
        else { throw AppError.parseFailed }
        return .init(text[rangeA.upperBound..<rangeB.lowerBound])
    }

    /// The image and (if offered) original image URL on a single image page. `index` is
    /// passed through so results can be collected.
    public static func parseGalleryNormalImageURL(doc: HTMLDocument, index: Int) throws -> (Int, URL, URL?) {
        guard let i3Node = doc.at_xpath("//div [@id='i3']"),
              let imageURLString = i3Node.at_css("img")?["src"],
              let imageURL = URL(string: imageURLString)
        else { throw AppError.parseFailed }

        guard let i7Node = doc.at_xpath("//div [@id='i7']"),
              let originalImageURLString = i7Node.at_xpath("//a")?["href"],
              let originalImageURL = URL(string: originalImageURLString)
        else { return (index, imageURL, nil) }

        return (index, imageURL, originalImageURL)
    }
}
