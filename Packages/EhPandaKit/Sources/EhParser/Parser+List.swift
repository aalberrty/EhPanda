import EhModels
import Foundation
import Kanna

// Note: Kanna evaluates an XPath that starts with `//` on a non-root node as `.//`, i.e. within
// that node. Queries are kept verbatim from legacy.

// MARK: Galleries

extension Parser {
    /// Parses any gallery list page (front page, watched, popular, favorites, toplists) in
    /// whichever display mode the site rendered it.
    ///
    /// - Throws: `AppError.ipBanned` when the page is empty because of an IP ban.
    public static func parseGalleries(doc: HTMLDocument) throws -> [Gallery] {
        let galleries: [Gallery]
        switch try? ListParser.parseDisplayMode(doc: doc) {
        case "Minimal":
            galleries = ListParser.parseMinimalModeGalleries(doc: doc, parsesTags: false)
        case "Minimal+":
            galleries = ListParser.parseMinimalModeGalleries(doc: doc, parsesTags: true)
        case "Compact":
            galleries = ListParser.parseCompactModeGalleries(doc: doc)
        case "Extended":
            galleries = ListParser.parseExtendedModeGalleries(doc: doc)
        case "Thumbnail":
            galleries = ListParser.parseThumbnailModeGalleries(doc: doc)
        default:
            // Toplists doesn't have a display mode selector and it's compact mode
            galleries = ListParser.parseCompactModeGalleries(doc: doc)
        }

        if galleries.isEmpty, let banInterval = parseBanInterval(doc: doc) {
            throw AppError.ipBanned(banInterval)
        }
        return galleries
    }
}

// MARK: Display modes

enum ListParser {
    static func parseMinimalModeGalleries(doc: HTMLDocument, parsesTags: Bool) -> [Gallery] {
        var galleries = [Gallery]()
        for link in doc.xpath("//tr") {
            let gltmNode = link.at_xpath("//div [@class='gltm']")
            let tags = (try? parseGalleryTags(node: gltmNode)) ?? []
            guard let gl2mNode = link.at_xpath("//td [@class='gl2m']"),
                  let gl3mNode = link.at_xpath("//td [@class='gl3m glname']"),
                  let panel = try? parseThumbnailPanel(node: gl2mNode),
                  let (galleryTitle, galleryURL) = try? parseGalleryTitle(node: gl3mNode)
            else { continue }
            galleries.append(
                makeGallery(
                    title: galleryTitle, url: galleryURL, panel: panel,
                    tags: parsesTags ? tags : [], uploader: try? parseUploader(node: link)
                )
            )
        }
        return galleries
    }

    static func parseCompactModeGalleries(doc: HTMLDocument) -> [Gallery] {
        var galleries = [Gallery]()
        for link in doc.xpath("//tr") {
            guard let gl2cNode = link.at_xpath("//td [@class='gl2c']"),
                  let gl3cNode = link.at_xpath("//td [@class='gl3c glname']"),
                  let panel = try? parseThumbnailPanel(node: gl2cNode),
                  let (galleryTitle, galleryURL) = try? parseGalleryTitle(node: gl3cNode)
            else { continue }
            galleries.append(
                makeGallery(
                    title: galleryTitle, url: galleryURL, panel: panel,
                    tags: (try? parseGalleryTags(node: gl3cNode)) ?? [],
                    uploader: try? parseUploader(node: link)
                )
            )
        }
        return galleries
    }

    static func parseExtendedModeGalleries(doc: HTMLDocument) -> [Gallery] {
        var galleries = [Gallery]()
        for link in doc.xpath("//tr") {
            guard let gl3eSiblingNode = link.at_xpath("//div [@class='gl3e']")?.nextSibling,
                  let panel = try? parseThumbnailPanel(node: link),
                  let (galleryTitle, galleryURL) = try? parseGalleryTitle(node: gl3eSiblingNode)
            else { continue }
            galleries.append(
                makeGallery(
                    title: galleryTitle, url: galleryURL, panel: panel,
                    tags: (try? parseGalleryTags(node: gl3eSiblingNode)) ?? [],
                    uploader: panel.uploader
                )
            )
        }
        return galleries
    }

    static func parseThumbnailModeGalleries(doc: HTMLDocument) -> [Gallery] {
        var galleries = [Gallery]()
        for link in doc.xpath("//div [@class='gl1t']") {
            let gl6tNode = link.at_xpath("//div [@class='gl6t']")
            guard let panel = try? parseThumbnailPanel(node: link),
                  let (galleryTitle, galleryURL) = try? parseGalleryTitle(node: link)
            else { continue }
            galleries.append(
                makeGallery(
                    title: galleryTitle, url: galleryURL, panel: panel,
                    tags: (try? parseGalleryTags(node: gl6tNode)) ?? [], uploader: nil
                )
            )
        }
        return galleries
    }

    private static func makeGallery(
        title: String, url: URL, panel: ThumbnailPanel, tags: [GalleryTag], uploader: String?
    ) -> Gallery {
        // `parseGalleryTitle` guarantees at least four path components.
        Gallery(
            gid: url.pathComponents[2],
            token: url.pathComponents[3],
            title: title,
            rating: panel.rating,
            tags: tags,
            category: panel.category,
            uploader: uploader,
            pageCount: panel.pageCount,
            postedDate: panel.publishedDate,
            coverURL: panel.coverURL,
            galleryURL: url
        )
    }
}

// MARK: Shared pieces

extension ListParser {
    struct ThumbnailPanel {
        let coverURL: URL
        let category: EhModels.Category
        let rating: Float
        let publishedDate: Date
        let pageCount: Int
        let uploader: String?
    }

    static func parseDisplayMode(doc: HTMLDocument) throws -> String {
        guard let containerNode = doc.at_xpath("//div [@id='dms']") ?? doc.at_xpath("//div [@class='searchnav']")
        else { throw AppError.parseFailed }

        var dmsNode: Kanna.XMLElement?
        for select in containerNode.xpath("//select") where select["onchange"]?.contains("inline_set=dm_") == true {
            dmsNode = select
            break
        }
        guard let dmsNode else { throw AppError.parseFailed }

        for option in dmsNode.xpath("//option") where option["selected"] == "selected" {
            if let displayMode = option.text {
                return displayMode
            }
        }
        throw AppError.parseFailed
    }

    static func parseThumbnailPanel(node: Kanna.XMLElement) throws -> ThumbnailPanel {
        var tmpCoverURL: URL?
        var tmpCategory: EhModels.Category?
        var tmpPublishedDate: Date?
        var tmpPageCount: Int?
        var uploader: String?

        for div in node.xpath("//div") {
            if let imgNode = div.at_css("img"),
               let urlString = imgNode["data-src"] ?? imgNode["src"], let url = URL(string: urlString),
               [SiteImageURL.torrentDownload, SiteImageURL.torrentDownloadInvalid]
                .contains(where: { $0 == urlString }) == false, imgNode["alt"] != "T"
            {
                tmpCoverURL = url
            }
            if let rawValue = div.text, let category = EhModels.Category(rawValue: rawValue) {
                tmpCategory = category
            }
            if let onClick = div["onclick"], !onClick.isEmpty, let dateString = div.text,
               let date = try? Parser.parseDate(time: dateString, format: DateFormat.publish)
            {
                tmpPublishedDate = date
            }
            if let components = div.text?.split(separator: " "), components.count == 2,
               ["page", "pages"].contains(components[1]), let pageCount = Int(components[0])
            {
                tmpPageCount = pageCount
            }
            // Extended display mode uses this
            if let aLink = div.at_xpath("//a"), aLink["href"]?.contains("uploader") == true {
                uploader = aLink.text
            } else if div.text == "(Disowned)" {
                uploader = div.text
            }
        }

        guard let coverURL = tmpCoverURL,
              let category = tmpCategory,
              let (rating, _, _) = try? Parser.parseRating(node: node),
              let publishedDate = tmpPublishedDate,
              let pageCount = tmpPageCount
        else { throw AppError.parseFailed }
        return ThumbnailPanel(
            coverURL: coverURL, category: category, rating: rating,
            publishedDate: publishedDate, pageCount: pageCount, uploader: uploader
        )
    }

    static func parseGalleryTitle(node: Kanna.XMLElement) throws -> (String, URL) {
        func findTitle(glink: Kanna.XMLElement) throws -> (String, URL) {
            guard let glinkParentNode = glink.parent,
                  let glinkGrandParentNode = glinkParentNode.parent,
                  let title = glink.text,
                  let urlString = glinkParentNode["href"] ?? glinkGrandParentNode["href"],
                  let url = URL(string: urlString),
                  url.pathComponents.count >= 4
            else { throw AppError.parseFailed }
            return (title, url)
        }

        for glink in node.xpath("//div") where glink.className?.contains("glink") == true {
            if let result = try? findTitle(glink: glink) {
                return result
            }
        }
        for glink in node.xpath("//span") where glink.className?.contains("glink") == true {
            if let result = try? findTitle(glink: glink) {
                return result
            }
        }
        throw AppError.parseFailed
    }

    static func parseGalleryTags(node: Kanna.XMLElement?) throws -> [GalleryTag] {
        guard let node = node else { throw AppError.parseFailed }
        var tags = [GalleryTag]()
        for tagLink in node.xpath("//div")
        where ["gt", "gtl"].contains(tagLink.className) && tagLink["title"]?.isEmpty == false {
            guard let titleComponents = tagLink["title"]?.split(separator: ":"),
                  titleComponents.count == 2
            else { continue }
            let namespace = String(titleComponents[0])
            let content = GalleryTag.Content(
                rawNamespace: namespace, text: String(titleComponents[1]),
                isVotedUp: false, isVotedDown: false,
                backgroundColor: tagLink["style"].flatMap(parseTagBackgroundColor(style:))
            )
            if let index = tags.firstIndex(where: { $0.rawNamespace == namespace }) {
                tags[index] = .init(rawNamespace: namespace, contents: tags[index].contents + [content])
            } else {
                tags.append(.init(rawNamespace: namespace, contents: [content]))
            }
        }
        return tags
    }

    /// The highlight of a watched tag, e.g. `background:radial-gradient(#ff8800,#…)`.
    /// The text colour legacy stored alongside is derived from it (`RGBColor.isLight`).
    static func parseTagBackgroundColor(style: String) -> RGBColor? {
        guard let rangeB = style.range(of: ",#"),
              let rangeA = style.range(of: "background:radial-gradient(#"),
              rangeA.upperBound <= rangeB.lowerBound
        else { return nil }
        let hex = String(style[rangeA.upperBound..<rangeB.lowerBound])
        guard hex.count == 6, let red = Int(hex.prefix(2), radix: 16),
              let green = Int(hex.prefix(4).suffix(2), radix: 16),
              let blue = Int(hex.suffix(2), radix: 16)
        else { return nil }
        return RGBColor(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    static func parseUploader(node: Kanna.XMLElement) throws -> String {
        var tmpUploader: String?
        for link in node.xpath("//td") where link.className?.contains("glhide") == true {
            for divLink in link.xpath("//div")
            where ["page", "pages"].contains(where: { divLink.text?.contains($0) != false }) == false {
                if let aLink = divLink.at_xpath("//a"),
                   aLink["href"]?.contains("uploader") == true,
                   let aText = aLink.text
                {
                    tmpUploader = aText
                } else if divLink.text == "(Disowned)" {
                    tmpUploader = divLink.text
                }
            }
        }
        guard let uploader = tmpUploader else { throw AppError.parseFailed }
        return uploader
    }
}
