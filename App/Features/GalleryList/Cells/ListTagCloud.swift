import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The tags of a list row or of the long-press peek (legacy `TagCloudView` in
/// `GalleryDetailCell`), translated with a dictionary lookup in `TagTranslationService` when the
/// setting is on. Plain tags are quiet pills; a watched tag keeps the highlight the site gives it.
struct ListTagCloud: View {
    let tags: [GalleryTag.Content]
    var font: Font = .caption2
    var padding = EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)

    @Environment(SettingsStore.self) private var settings
    // Optional so the cells still render where the service is not injected (previews).
    @Environment(TagTranslationService.self) private var tagTranslations: TagTranslationService?

    var body: some View {
        let translations = settings.translatesTags ? tagTranslations : nil
        let showsImages = settings.showsImagesInTags
        FlowLayout(spacing: Tokens.Spacing.xSmall) {
            ForEach(tags) { content in
                let display = translations?.display(forKey: content.rawNamespace + content.text)
                TagChip(
                    content.chipText(translation: display, showsImages: showsImages),
                    imageURL: showsImages ? display?.valueImageURL : nil,
                    font: font,
                    padding: padding,
                    foreground: content.backgroundColor == nil ? .textSecondary : content.textColor ?? .textSecondary,
                    background: content.backgroundColor?.color ?? .chipFill
                )
            }
        }
    }
}
