import EhDatabase
import EhFeatures
import EhModels
import Testing

@Suite struct TagChipTextTests {
    private let content = GalleryTag.Content(
        rawNamespace: "other", text: "non-h imageset", isVotedUp: false, isVotedDown: false, backgroundColor: nil
    )

    @Test func translationKeepsEmojiOnlyWithImages() {
        let translation = TagTranslationDisplay(displayValue: "非H图集 🐱", valueImageURL: nil)
        #expect(content.chipText(translation: translation, showsImages: true) == "非H图集 🐱")
        #expect(content.chipText(translation: translation, showsImages: false) == "非H图集 ")
    }

    @Test func fallsBackToTheTagWithoutATranslation() {
        let empty = TagTranslationDisplay(displayValue: "", valueImageURL: nil)
        #expect(content.chipText(translation: nil, showsImages: false) == "non-h imageset")
        #expect(content.chipText(translation: empty, showsImages: true) == "non-h imageset")
    }
}
