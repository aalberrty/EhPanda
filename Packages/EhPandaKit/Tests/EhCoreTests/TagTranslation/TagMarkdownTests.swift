import EhDatabase
import EhModels
import Foundation
import Testing
@testable import EhCore

/// Expectations were produced by running legacy's `MarkdownUtil` (SwiftCommonMark 0.30.2) on
/// these inputs.
@Suite struct TagMarkdownTests {
    struct ValueCase: Sendable, CustomTestStringConvertible {
        let value: String
        let display: String
        let image: String?

        var testDescription: String { value.debugDescription }
    }

    static let icons = "https://raw.githubusercontent.com/wiki/EhTagTranslation/Database/database-icon/"
    static let photo = "https://ehgt.org/91/fe/91fe1db07742e349063b92141cb10617b8614359-186457-1060-1493-jpg_l.jpg"

    static let valueCases: [ValueCase] = [
        .init(value: "巨乳", display: "巨乳", image: nil),
        .init(value: "  巨乳  ", display: "巨乳", image: nil),
        // Image, then text.
        .init(value: "![精灵球图标](\(icons)pokemon.webp)宝可梦", display: "宝可梦", image: "\(icons)pokemon.webp"),
        .init(
            value: "![](https://lain.bgm.tv/r/400/pic/cover/l/56/33/208559_6jzc1.jpg) 碧蓝航线",
            display: " 碧蓝航线", image: "https://lain.bgm.tv/r/400/pic/cover/l/56/33/208559_6jzc1.jpg"
        ),
        // Text, then image.
        .init(value: "可爱的艾露露![图](\(photo))", display: "可爱的艾露露", image: photo),
        // The URL hidden in the image title.
        .init(value: "![扶她图标](# \"\(icons)futanari.webp\")扶她", display: "扶她", image: "\(icons)futanari.webp"),
        .init(
            value: "![LL](\(icons)love%20live.webp)LoveLive!Sunshine!!",
            display: "LoveLive!Sunshine!!", image: "\(icons)love%20live.webp"
        ),
        .init(value: "Little Busters!", display: "Little Busters!", image: nil),
        .init(value: #"Porty\_ramram"#, display: "Porty_ramram", image: nil),
        .init(value: #"\*Cherish\*"#, display: "*Cherish*", image: nil),
        // Emphasis is not a text node, so the first text comes after it.
        .init(value: "**不**算", display: "算", image: nil),
        .init(value: "`code`后文", display: "后文", image: nil),
        // A value with no top-level text falls back to the raw value.
        .init(
            value: "[萌娘百科](https://zh.moegirl.org.cn/Angel_Beats)",
            display: "[萌娘百科](https://zh.moegirl.org.cn/Angel_Beats)", image: nil
        ),
        .init(value: "骑士&魔法", display: "骑士&魔法", image: nil),
        .init(value: "&amp;", display: "&", image: nil),
        .init(value: "# 标题", display: "# 标题", image: nil),
        .init(value: "1. 绮良良", display: "1. 绮良良", image: nil),
        .init(value: "> 引用", display: "> 引用", image: nil),
        .init(value: "第一行\n第二行", display: "第一行", image: nil),
        .init(value: "", display: "", image: nil),
        .init(value: "   ", display: "   ", image: nil),
        // A destination with a space is not a link, so it stays text.
        .init(value: "![坏](not a url)文字", display: "![坏](not a url)文字", image: nil)
    ]

    @Test(arguments: valueCases)
    func valueDisplayMatchesLegacy(_ testCase: ValueCase) {
        let display = TagTranslationPreparation.display(of: translation(value: testCase.value))
        #expect(display.displayValue == testCase.display)
        #expect(display.valueImageURL?.absoluteString == testCase.image)
    }

    @Test func fastPathAgreesWithParser() {
        for value in ["巨乳", "  巨乳  ", "Big Breasts", "1号", "#tag", "- x", "Ｆｕｌｌ　ｃｏｌｏｒ"] {
            let parsed = TagMarkdown.texts(value).first ?? value
            #expect(TagMarkdown.display(of: value, validator: URLValidator()).text == parsed, "\(value)")
        }
        #expect(TagMarkdown.plainParagraphText("  巨乳 ") == "巨乳")
        #expect(TagMarkdown.plainParagraphText("1号") == nil)
        #expect(TagMarkdown.plainParagraphText("a!") == nil)
    }

    @Test func descriptionWithBackticksAndImage() {
        let translation = translation(
            value: "x",
            description: "西方的这类是`misc`类别。![分类流程图](https://ehwiki.org/images/b/be/flowchartChinese.png)",
            links: #"[维基百科](https://zh.wikipedia.org/wiki/三国演义_%28动画%29) (\*)"#
        )
        #expect(TagTranslationPreparation.descriptionPlainText(of: translation) == "西方的这类是 misc 类别。")
        #expect(TagTranslationPreparation.descriptionImageURLs(of: translation).map(\.absoluteString)
            == ["https://ehwiki.org/images/b/be/flowchartChinese.png"])
        // Legacy's `URL(string:)` percent-encodes the existing escapes again; kept as is.
        #expect(TagTranslationPreparation.links(of: translation).map(\.absoluteString) == [
            "https://zh.wikipedia.org/wiki/%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89_%2528%E5%8A%A8%E7%94%BB%2529"
        ])
    }

    @Test func descriptionSkipsQuotesAndEmphasisAndJoinsLines() {
        let description = """
            打扮为一般普通护士或女佣等，而不是特定角色的**不**算。
            第二行`lolicon`

            > “引用” （翻译自pixiv简介）
            ![图](https://pbs.twimg.com/a.jpg)

            ![图](# "https://ehgt.org/b5/24/b524.jpg")![图](https://ehgt.org/12/6e/126e.jpg)
            """
        let translation = translation(
            value: "x", description: description,
            links: "[Twitter](https://twitter.com/miku7zu7) [pixiv](https://www.pixiv.net/users/2405344)"
        )
        #expect(TagTranslationPreparation.descriptionPlainText(of: translation)
            == "打扮为一般普通护士或女佣等，而不是特定角色的算。第二行 lolicon")
        // The image after the quote is a lazy continuation of it, so legacy skipped it.
        #expect(TagTranslationPreparation.descriptionImageURLs(of: translation).map(\.absoluteString)
            == ["https://ehgt.org/b5/24/b524.jpg", "https://ehgt.org/12/6e/126e.jpg"])
        #expect(TagTranslationPreparation.links(of: translation).map(\.absoluteString)
            == ["https://twitter.com/miku7zu7", "https://www.pixiv.net/users/2405344"])
    }

    @Test func emptyAndMissingDescription() {
        let empty = translation(value: "x", description: "", links: "")
        #expect(TagTranslationPreparation.descriptionPlainText(of: empty) == "")
        #expect(TagTranslationPreparation.descriptionImageURLs(of: empty).isEmpty)
        #expect(TagTranslationPreparation.links(of: empty).isEmpty)
        #expect(TagTranslationPreparation.descriptionPlainText(of: translation(value: "x")) == nil)
    }

    @Test func detailRequiresDescriptionText() {
        func stored(_ description: String?) -> StoredTagTranslation {
            StoredTagTranslation(
                key: "femalex",
                translation: translation(value: "叉", description: description, links: "[a](https://a.b/)"),
                displayValue: "叉", valueImageURL: nil
            )
        }
        #expect(TagTranslationPreparation.detail(of: stored(nil)) == nil)
        #expect(TagTranslationPreparation.detail(of: stored("![图](https://ehgt.org/a.jpg)")) == nil)
        #expect(TagTranslationPreparation.detail(of: stored("说明![图](https://ehgt.org/a.jpg)")) == TagDetail(
            title: "叉", description: "说明",
            imageURLs: [URL(string: "https://ehgt.org/a.jpg")!], links: [URL(string: "https://a.b/")!]
        ))
    }

    private func translation(value: String, description: String? = nil, links: String? = nil) -> TagTranslation {
        TagTranslation(namespace: .female, key: "x", value: value, description: description, linksString: links)
    }
}
