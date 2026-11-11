import EhModels
import Foundation
import Kanna

// MARK: Detail

extension Parser {
    /// The gallery a single image page (`/s/…`) belongs to.
    public static func parseGalleryURL(doc: HTMLDocument) throws -> URL {
        guard let galleryURLString = doc.at_xpath("//div [@class='sb']")?.at_xpath("//a")?["href"],
              let galleryURL = URL(string: galleryURLString) else { throw AppError.parseFailed }
        return galleryURL
    }

    /// Parses a gallery detail page. The detail page is also the gallery's first preview page:
    /// the state carries its thumbnails (`previewURLs`) and its viewer links (`thumbnailURLs`,
    /// legacy's name for them).
    ///
    /// - Throws: `AppError.copyrightClaim` or `.expunged` when the site shows a removal
    ///   notice, `.ipBanned` for a ban page, otherwise `.parseFailed`.
    public static func parseGalleryDetail(doc: HTMLDocument, gid: String) throws -> (GalleryDetail, GalleryState) {
        for link in doc.xpath("//div [@class='gm']") {
            guard let detail = DetailParser.parseDetail(doc: doc, gmNode: link, gid: gid) else { continue }
            let state = GalleryState(
                gid: gid,
                tags: detail.tags,
                previewURLs: detail.previewPage.previewURLs,
                previewConfig: try? DetailParser.parsePreviewConfig(doc: doc),
                comments: parseComments(doc: doc),
                thumbnailURLs: detail.previewPage.pageURLs
            )
            return (detail.detail, state)
        }

        if let reason = doc.at_xpath("//div [@class='d']")?.at_xpath("//p")?.text {
            if let rangeA = reason.range(of: "copyright claim by "),
               let rangeB = reason.range(of: ".Sorry about that."),
               rangeA.upperBound <= rangeB.lowerBound
            {
                let owner = String(reason[rangeA.upperBound..<rangeB.lowerBound])
                throw AppError.copyrightClaim(owner)
            } else {
                throw AppError.expunged(reason)
            }
        } else if let banInterval = parseBanInterval(doc: doc) {
            throw AppError.ipBanned(banInterval)
        } else {
            throw AppError.parseFailed
        }
    }

    /// The API key embedded in a gallery detail page's script.
    public static func parseAPIKey(doc: HTMLDocument) throws -> String {
        var tmpKey: String?

        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let script = link.text, script.contains("apikey"),
                  let rangeA = script.range(of: ";\nvar apikey = \""),
                  let rangeB = script.range(of: "\";\nvar average_rating"),
                  rangeA.upperBound <= rangeB.lowerBound
            else { continue }

            tmpKey = String(script[rangeA.upperBound..<rangeB.lowerBound])
        }

        guard let apikey = tmpKey
        else { throw AppError.parseFailed }

        return apikey
    }

    /// The archiver URL from an "Archive Download" link's `onclick`.
    public static func parseArchiveURL(node: Kanna.XMLElement) throws -> URL {
        var archiveURL: URL?
        if let aLink = node.at_xpath("//a"),
           aLink.text?.contains("Archive Download") == true, let onClick = aLink["onclick"],
           let rangeA = onClick.range(of: "popUp('"), let rangeB = onClick.range(of: "',"),
           rangeA.upperBound <= rangeB.lowerBound
        {
            archiveURL = URL(string: .init(onClick[rangeA.upperBound..<rangeB.lowerBound]))
        }

        if let url = archiveURL {
            return url
        } else {
            throw AppError.parseFailed
        }
    }
}

// MARK: Pieces

enum DetailParser {
    struct Parsed {
        let detail: GalleryDetail
        let tags: [GalleryTag]
        let previewPage: PreviewPage
    }

    // Mirrors the legacy guard chain: any missing piece skips this `div.gm`.
    static func parseDetail(doc: HTMLDocument, gmNode link: Kanna.XMLElement, gid: String) -> Parsed? {
        guard let gd3Node = link.at_xpath("//div [@id='gd3']"),
              let gd4Node = link.at_xpath("//div [@id='gd4']"),
              let gd5Node = link.at_xpath("//div [@id='gd5']"),
              let gddNode = gd3Node.at_xpath("//div [@id='gdd']"),
              let gdrNode = gd3Node.at_xpath("//div [@id='gdr']"),
              let gdfNode = gd3Node.at_xpath("//div [@id='gdf']"),
              let coverURL = try? parseCoverURL(node: link),
              let tags = try? parseGalleryTags(node: gd4Node),
              let previewPage = try? Parser.parsePreviewPage(doc: doc),
              let arcAndTor = try? parseArcAndTor(node: gd5Node),
              let infoPanel = try? parseInfoPanel(node: gddNode),
              let visibility = try? parseVisibility(value: infoPanel[2]),
              let sizeCount = Float(infoPanel[4]),
              let pageCount = Int(infoPanel[6]),
              let favoritedCount = Int(infoPanel[7]),
              let language = Language(rawValue: infoPanel[3]),
              let engTitle = link.at_xpath("//h1 [@id='gn']")?.text,
              let uploader = try? parseUploader(node: gd3Node),
              let (imgRating, textRating, containsUserRating) = try? Parser.parseRating(node: gdrNode),
              let ratingCount = Int(gdrNode.at_xpath("//span [@id='rating_count']")?.text ?? ""),
              let category = EhModels.Category(rawValue: gd3Node.at_xpath("//div [@id='gdc']")?.text ?? ""),
              let postedDate = try? Parser.parseDate(time: infoPanel[0], format: DateFormat.publish)
        else { return nil }

        let isFavorited = gdfNode
            .at_xpath("//a [@id='favoritelink']")?
            .text?.contains("Add to Favorites") == false
        let gjText = link.at_xpath("//h1 [@id='gj']")?.text
        let jpnTitle = gjText?.isEmpty != false ? nil : gjText
        let parentURLString = infoPanel[1].isValidURL ? infoPanel[1] : ""

        let detail = GalleryDetail(
            gid: gid,
            title: engTitle,
            jpnTitle: jpnTitle,
            isFavorited: isFavorited,
            visibility: visibility,
            rating: containsUserRating ? textRating ?? 0.0 : imgRating,
            userRating: containsUserRating ? imgRating : 0.0,
            ratingCount: ratingCount,
            category: category,
            language: language,
            uploader: uploader,
            postedDate: postedDate,
            coverURL: coverURL,
            archiveURL: arcAndTor.0,
            parentURL: URL(string: parentURLString),
            favoritedCount: favoritedCount,
            pageCount: pageCount,
            sizeCount: sizeCount,
            sizeType: infoPanel[5],
            torrentCount: arcAndTor.1
        )
        return Parsed(detail: detail, tags: tags, previewPage: previewPage)
    }

    static func parsePreviewConfig(doc: HTMLDocument) throws -> PreviewConfig {
        guard let previewMode = try? Parser.parsePreviewMode(doc: doc),
              let gpcText = doc.at_xpath("//p [@class='gpc']")?.text,
              let rangeA = gpcText.range(of: "Showing 1 - "),
              let rangeB = gpcText.range(of: " of "),
              rangeA.upperBound <= rangeB.lowerBound,
              let singlePageCount = Int(gpcText[rangeA.upperBound..<rangeB.lowerBound])
        else { throw AppError.parseFailed }

        let isLargePreview = previewMode == "gt200"
        let factor = isLargePreview ? 1 : 2
        let rowsCount =
            switch singlePageCount {
            case _ where singlePageCount <= 20 * factor: 4
            case _ where singlePageCount <= 40 * factor: 8
            case _ where singlePageCount <= 100 * factor: 20
            case _ where singlePageCount <= 200 * factor: 40
            default: 4
            }
        return isLargePreview ? .large(rows: rowsCount) : .normal(rows: rowsCount)
    }

    static func parseCoverURL(node: Kanna.XMLElement?) throws -> URL {
        guard let coverHTML = node?.at_xpath("//div [@id='gd1']")?.innerHTML,
              let rangeA = coverHTML.range(of: "url("), let rangeB = coverHTML.range(of: ")"),
              rangeA.upperBound <= rangeB.lowerBound,
              let url = URL(string: .init(coverHTML[rangeA.upperBound..<rangeB.lowerBound]))
        else { throw AppError.parseFailed }

        return url
    }

    static func parseGalleryTags(node: Kanna.XMLElement) throws -> [GalleryTag] {
        var tags = [GalleryTag]()
        for link in node.xpath("//tr") {
            guard let tcText = link.at_xpath("//td [@class='tc']")?.text else { continue }
            let namespace = String(tcText.dropLast())
            var contents = [GalleryTag.Content]()
            for divLink in link.xpath("//div") {
                guard var text = divLink.text, let aClass = divLink.at_xpath("//a")?.className else { continue }
                if let range = text.range(of: " | ") {
                    text = .init(text[..<range.lowerBound])
                }
                contents.append(
                    .init(
                        rawNamespace: namespace, text: text,
                        isVotedUp: aClass == "tup",
                        isVotedDown: aClass == "tdn",
                        backgroundColor: nil
                    )
                )
            }

            tags.append(.init(rawNamespace: namespace, contents: contents))
        }

        return tags
    }

    static func parseArcAndTor(node: Kanna.XMLElement?) throws -> (URL?, Int) {
        guard let node = node else { throw AppError.parseFailed }

        var archiveURL: URL?
        for g2gspLink in node.xpath("//p [@class='g2 gsp']") {
            if archiveURL == nil {
                archiveURL = try? Parser.parseArchiveURL(node: g2gspLink)
            } else {
                break
            }
        }

        var tmpTorrentCount: Int?
        for g2Link in node.xpath("//p [@class='g2']") {
            if let aText = g2Link.at_xpath("//a")?.text,
               let rangeA = aText.range(of: "Torrent Download ("),
               let rangeB = aText.range(of: ")"),
               rangeA.upperBound <= rangeB.lowerBound
            {
                tmpTorrentCount = Int(aText[rangeA.upperBound..<rangeB.lowerBound])
            }
            if archiveURL == nil {
                archiveURL = try? Parser.parseArchiveURL(node: g2Link)
            }
        }

        guard let torrentCount = tmpTorrentCount
        else { throw AppError.parseFailed }

        return (archiveURL, torrentCount)
    }

    /// The `#gdd` table as `[posted, parent, visible, language, size, size unit, length,
    /// favorited]`; throws unless all eight were found.
    static func parseInfoPanel(node: Kanna.XMLElement?) throws -> [String] {
        guard let object = node?.xpath("//tr")
        else { throw AppError.parseFailed }

        var infoPanel = Array(repeating: "", count: 8)
        for gddLink in object {
            guard let gdt1Text = gddLink.at_xpath("//td [@class='gdt1']")?.text,
                  let gdt2Text = gddLink.at_xpath("//td [@class='gdt2']")?.text
            else { continue }
            let aHref = gddLink.at_xpath("//td [@class='gdt2']")?.at_xpath("//a")?["href"]

            if gdt1Text.contains("Posted") {
                infoPanel[0] = gdt2Text
            }
            if gdt1Text.contains("Parent") {
                infoPanel[1] = aHref ?? "None"
            }
            if gdt1Text.contains("Visible") {
                infoPanel[2] = gdt2Text
            }
            if gdt1Text.contains("Language") {
                let words = gdt2Text.split(separator: " ")
                if !words.isEmpty {
                    infoPanel[3] = words[0]
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            if gdt1Text.contains("File Size") {
                infoPanel[4] = gdt2Text
                    .replacingOccurrences(of: " KiB", with: "")
                    .replacingOccurrences(of: " MiB", with: "")
                    .replacingOccurrences(of: " GiB", with: "")

                if gdt2Text.contains("KiB") { infoPanel[5] = "KiB" }
                if gdt2Text.contains("MiB") { infoPanel[5] = "MiB" }
                if gdt2Text.contains("GiB") { infoPanel[5] = "GiB" }
            }
            if gdt1Text.contains("Length") {
                infoPanel[6] = gdt2Text.replacingOccurrences(of: " pages", with: "")
            }
            if gdt1Text.contains("Favorited") {
                infoPanel[7] = gdt2Text
                    .replacingOccurrences(of: " times", with: "")
                    .replacingOccurrences(of: "Never", with: "0")
                    .replacingOccurrences(of: "Once", with: "1")
            }
        }

        guard infoPanel.filter({ !$0.isEmpty }).count == 8
        else { throw AppError.parseFailed }

        return infoPanel
    }

    static func parseVisibility(value: String) throws -> GalleryVisibility {
        guard value != "Yes" else { return .yes }
        guard let rangeA = value.range(of: "("),
              let rangeB = value.range(of: ")"),
              rangeA.upperBound <= rangeB.lowerBound
        else { throw AppError.parseFailed }

        let reason = String(value[rangeA.upperBound..<rangeB.lowerBound])
        return .no(reason: reason)
    }

    static func parseUploader(node: Kanna.XMLElement?) throws -> String {
        guard let gdnNode = node?.at_xpath("//div [@id='gdn']") else {
            throw AppError.parseFailed
        }

        if let aText = gdnNode.at_xpath("//a")?.text {
            return aText
        } else if let gdnText = gdnNode.text {
            return gdnText
        } else {
            throw AppError.parseFailed
        }
    }
}
