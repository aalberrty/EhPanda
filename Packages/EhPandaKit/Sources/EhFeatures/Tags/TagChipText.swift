import EhDatabase
import EhModels

extension GalleryTag.Content {
    /// A tag chip's text, on the detail screen and in list cells alike: the translation when
    /// there is one, without emoji when images in tags are off (legacy `TagCloudCell`),
    /// otherwise the tag itself.
    public nonisolated func chipText(translation: TagTranslationDisplay?, showsImages: Bool) -> String {
        guard let translation, !translation.displayValue.isEmpty else { return text }
        return showsImages ? translation.displayValue : translation.displayValue.removingEmojiPresentation
    }
}

extension String {
    /// Drops characters that render as emoji by default, like legacy `emojisRipped`.
    public nonisolated var removingEmojiPresentation: String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: unicodeScalars.filter { !$0.properties.isEmojiPresentation })
        return String(scalars)
    }
}
