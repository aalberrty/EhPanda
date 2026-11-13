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

    @Test func entitiesInPlainTextAreDecoded() throws {
        let result = try contents(
            #"&gt;GURU said 1 &lt; 2 &amp;&amp; &quot;yes&quot; it&#39;s&nbsp;fine &#12354;&#x3042;"#
        )
        #expect(summary(result) == ["plainText|>GURU said 1 < 2 && \"yes\" it's\u{00A0}fine ああ"])
    }

    @Test func entitiesAroundALinkAreDecoded() throws {
        let result = try contents(
            #"&gt;&gt;5143504 <a href="https://x.example/?a=1&amp;b=2">Tom &amp; Jerry</a> &lt;3"#
        )
        #expect(summary(result) == [
            "plainText|>>5143504",
            "linkedText|Tom & Jerry|https://x.example/?a=1&b=2",
            "plainText|<3"
        ])
    }

    @Test func entitiesKeepLineBreaks() throws {
        #expect(summary(try contents("a &gt; b<br>c &amp; d<br><br>e")) == ["plainText|a > b\nc & d\n\ne"])
    }

    @Test func entitiesBetweenImagesAreDecoded() throws {
        let result = try contents(
            #"<img src="https://i.example/1.png"> &gt; <a href="https://x.example/2"><img src="https://i.example/2.png"></a>"#
        )
        #expect(summary(result) == [
            "singleImg|https://i.example/1.png",
            "plainText|>",
            "linkedImg|https://x.example/2|https://i.example/2.png"
        ])
    }

    @Test func commentBodiesOnAPageAreDecoded() throws {
        let doc = try html(#"""
            <div id="cdiv"><div class="c1"><div class="c2"><div class="c3">Posted on 28 August 2022, 07:32 by: &nbsp; <a href="https://e-hentai.org/uploader/A">A</a></div></div>
            <div class="c6" id="comment_5143504">&gt;GURU<br>Agreed &amp; thanks</div></div></div>
            """#)
        let comment = try #require(Parser.parseComments(doc: doc).first)
        #expect(summary(comment.contents) == ["plainText|>GURU\nAgreed & thanks"])
    }
}
