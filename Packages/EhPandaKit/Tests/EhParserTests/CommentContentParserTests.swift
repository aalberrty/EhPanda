import EhModels
import Foundation
import Testing
@testable import EhParser

struct CommentContentParserTests {
    private func contents(_ body: String) throws -> [CommentContent] {
        let doc = try html(#"<div class="c6" id="comment_1">\#(body)</div>"#)
        return Parser.parseCommentContent(node: try #require(doc.at_xpath("//div [@class='c6']")))
    }

    private func summary(_ contents: [CommentContent]) -> [String] {
        contents.map { content in
            [
                "\(content.type)", content.text, content.link?.absoluteString, content.imgURL?.absoluteString,
                content.secondLink?.absoluteString, content.secondImgURL?.absoluteString
            ]
            .compactMap { $0 }
            .joined(separator: "|")
        }
    }

    @Test func plainTextWithLineBreaks() throws {
        #expect(summary(try contents("Hello<br>world<br />")) == ["plainText|Hello\nworld"])
    }

    @Test func textAroundALink() throws {
        let result = try contents(#"Before <a href="https://x.example/a">the link</a> after"#)
        #expect(summary(result) == [
            "plainText|Before",
            "linkedText|the link|https://x.example/a",
            "plainText|after"
        ])
    }

    @Test func singleLinkWithoutText() throws {
        // An empty anchor still has text (""), so legacy treats it as linked text and drops it.
        #expect(summary(try contents(#"<a href="https://x.example/a"></a>"#)).isEmpty)
    }

    @Test func adjacentImagesBecomeDoubleImage() throws {
        let result = try contents(#"<img src="https://i.example/1.png"><img src="https://i.example/2.png">"#)
        #expect(summary(result) == ["doubleImg|https://i.example/1.png|https://i.example/2.png"])
    }

    @Test func adjacentLinkedImagesBecomeDoubleLinkedImage() throws {
        let result = try contents(
            #"<a href="https://x.example/1"><img src="https://i.example/1.png"></a>"#
            + #"<a href="https://x.example/2"><img src="https://i.example/2.png"></a>"#
        )
        #expect(summary(result) == [
            "doubleLinkedImg|https://x.example/1|https://i.example/1.png|https://x.example/2|https://i.example/2.png"
        ])
    }

    @Test func spansAndNestedDivsAreDropped() throws {
        let result = try contents(#"Kept<span>dropped</span><div>also dropped</div>"#)
        #expect(summary(result) == ["plainText|Kept"])
    }
}
