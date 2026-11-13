import EhModels
import Foundation
import Kanna

// MARK: Comment

extension Parser {
    /// The comments on a gallery detail page.
    ///
    /// - Note: Strips each comment body's `div` and `span` children from `doc` while parsing
    ///   (see `parseCommentContent(node:)`), as legacy did.
    public static func parseComments(doc: HTMLDocument) -> [GalleryComment] {
        var comments = [GalleryComment]()
        for link in doc.xpath("//div [@id='cdiv']") {
            for c1Link in link.xpath("//div [@class='c1']") {
                if let comment = parseComment(c1Link: c1Link) {
                    comments.append(comment)
                }
            }
        }
        return comments
    }

    private static func parseComment(c1Link: Kanna.XMLElement) -> GalleryComment? {
        guard let c3Node = c1Link.at_xpath("//div [@class='c3']")?.text,
              let c6Node = c1Link.at_xpath("//div [@class='c6']"),
              let commentID = c6Node["id"]?
                .replacingOccurrences(of: "comment_", with: ""),
              let rangeA = c3Node.range(of: "Posted on "),
              // The site separates the author with a no-break space: "by: &nbsp; ".
              let rangeB = c3Node.range(of: " by: \u{00A0} "),
              rangeA.upperBound <= rangeB.lowerBound
        else { return nil }

        var score: String?
        if let c5Node = c1Link.at_xpath("//div [@class='c5 nosel']") {
            score = c5Node.at_xpath("//span")?.text
        }
        let author = String(c3Node[rangeB.upperBound...])
        let commentTime = String(c3Node[rangeA.upperBound..<rangeB.lowerBound])

        var votedUp = false
        var votedDown = false
        var votable = false
        var editable = false
        if let c4Link = c1Link.at_xpath("//div [@class='c4 nosel']") {
            for aLink in c4Link.xpath("//a") {
                guard let aId = aLink["id"],
                      let aStyle = aLink["style"]
                else {
                    if let aOnclick = aLink["onclick"],
                       aOnclick.contains("edit_comment") {
                        editable = true
                    }
                    continue
                }

                if aId.contains("vote_up") {
                    votable = true
                }
                if aId.contains("vote_up") && aStyle.contains("blue") {
                    votedUp = true
                }
                if aId.contains("vote_down") && aStyle.contains("blue") {
                    votedDown = true
                }
            }
        }

        guard let commentDate = try? parseDate(time: commentTime, format: DateFormat.comment)
        else { return nil }

        return GalleryComment(
            votedUp: votedUp,
            votedDown: votedDown,
            votable: votable,
            editable: editable,
            score: score,
            author: author,
            contents: parseCommentContent(node: c6Node),
            commentID: commentID,
            commentDate: commentDate
        )
    }
}

// MARK: CommentContent

extension Parser {
    /// Splits a comment body into runs of text, links and images.
    ///
    /// - Note: Mutates `node`: removes its `div` descendants, `span` children, and every
    ///   link and image as it consumes them.
    public static func parseCommentContent(node: Kanna.XMLElement) -> [CommentContent] {
        var contents = [CommentContent]()

        for div in node.xpath("//div") {
            node.removeChild(div)
        }
        for span in node.xpath("span") {
            node.removeChild(span)
        }

        guard var rawContent = node.innerHTML?
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "</span>", with: "")
        else { return [] }

        while (node.xpath("//a").count + node.xpath("//img").count) > 0 {
            guard let link = firstLinkOrImage(in: node, rawContent: rawContent),
                  let html = link.toHTML?
                    .replacingOccurrences(of: "<br>", with: "\n")
                    .replacingOccurrences(of: "</span>", with: ""),
                  let range = rawContent.range(of: html)
            // Legacy `continue`d here, which never terminates: nothing changed for the next pass.
            else { break }

            let text = String(rawContent[..<range.lowerBound])
            appendPlainText(text, to: &contents)
            appendLinkOrImage(link, to: &contents)

            rawContent.removeSubrange(..<range.upperBound)
            node.removeChild(link)

            if (node.xpath("//a").count + node.xpath("//img").count) <= 0 {
                appendPlainText(rawContent, to: &contents)
            }
        }

        if !rawContent.isEmpty && contents.isEmpty {
            appendPlainText(rawContent, to: &contents)
        }

        return contents
    }

    /// Whichever of the first `a` and first `img` comes first in `rawContent`.
    private static func firstLinkOrImage(in node: Kanna.XMLElement, rawContent: String) -> Kanna.XMLElement? {
        var tmpLink: Kanna.XMLElement?
        let links = [node.at_xpath("//a"), node.at_xpath("//img")].compactMap { $0 }

        for newLink in links {
            if tmpLink == nil {
                tmpLink = newLink
            } else if let tmpHTML = tmpLink?.toHTML,
                      let newHTML = newLink.toHTML,
                      let tmpBound = rawContent.range(of: tmpHTML)?.lowerBound,
                      let newBound = rawContent.range(of: newHTML)?.lowerBound,
                      newBound < tmpBound
            {
                tmpLink = newLink
            }
        }
        return tmpLink
    }

    /// Appends a run of the body's HTML between links and images as text.
    private static func appendPlainText(_ html: String, to contents: inout [CommentContent]) {
        let trimmed = decodedText(html).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        contents.append(CommentContent(type: .plainText, text: trimmed))
    }

    /// The text of a run of the body's HTML, which is cut from `innerHTML` and so still holds
    /// entities (`&gt;GURU`, `&amp;`, `&nbsp;`). libxml decodes them, and drops any tag the
    /// splitting left behind, the same way it reads a link's text. Line breaks are newlines
    /// by now, which it keeps.
    static func decodedText(_ html: String) -> String {
        guard html.contains("&") || html.contains("<"),
              let document = try? Kanna.HTML(html: html, encoding: .utf8),
              let text = document.body?.text
        else { return html }
        return text
    }

    private static func appendLinkOrImage(_ link: Kanna.XMLElement, to contents: inout [CommentContent]) {
        if let href = link["href"], let url = URL(string: href) {
            if let imgSrc = link.at_xpath("//img")?["src"],
               let imgURL = URL(string: imgSrc)
            {
                if let content = contents.last, content.type == .linkedImg {
                    contents.removeLast()
                    contents.append(
                        CommentContent(
                            type: .doubleLinkedImg,
                            link: content.link,
                            imgURL: content.imgURL,
                            secondLink: url,
                            secondImgURL: imgURL
                        )
                    )
                } else {
                    contents.append(CommentContent(type: .linkedImg, link: url, imgURL: imgURL))
                }
            } else if let text = link.text {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    contents.append(CommentContent(type: .linkedText, text: trimmed, link: url))
                }
            } else {
                contents.append(CommentContent(type: .singleLink, link: url))
            }
        } else if let src = link["src"], let url = URL(string: src) {
            if let content = contents.last, content.type == .singleImg {
                contents.removeLast()
                contents.append(CommentContent(type: .doubleImg, imgURL: content.imgURL, secondImgURL: url))
            } else {
                contents.append(CommentContent(type: .singleImg, imgURL: url))
            }
        }
    }
}
