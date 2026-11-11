import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The tags under a list cell's title (legacy `TagCloudView` in `GalleryDetailCell`), translated
/// with a dictionary lookup in `TagTranslationService` when the setting is on.
struct ListTagCloud: View {
    let tags: [GalleryTag.Content]

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
                    font: .caption2,
                    padding: EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4),
                    foreground: content.backgroundColor == nil ? .secondary : content.textColor ?? .secondary,
                    background: content.backgroundColor?.color ?? Color(.systemGray5)
                )
            }
        }
    }
}
