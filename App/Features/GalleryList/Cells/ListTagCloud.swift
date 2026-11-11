import EhCore
import EhModels
import SwiftUI

/// The tags under a list cell's title (legacy `TagCloudView` in `GalleryDetailCell`).
struct ListTagCloud: View {
    let tags: [GalleryTag.Content]

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        let translates = settings.translatesTags
        let showsImages = settings.showsImagesInTags
        FlowLayout(spacing: Tokens.Spacing.xSmall) {
            ForEach(tags) { content in
                let display = ListTagTranslation.display(of: content, translates: translates)
                TagChip(
                    display.text,
                    imageURL: showsImages ? display.imageURL : nil,
                    font: .caption2,
                    padding: EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4),
                    foreground: content.backgroundColor == nil ? .secondary : content.textColor ?? .secondary,
                    background: content.backgroundColor?.color ?? Color(.systemGray5)
                )
            }
        }
    }
}

/// The one place list cells translate a tag.
///
/// `TagTranslationService` is not on this branch yet. When it lands, this becomes a synchronous
/// dictionary lookup of `content.rawNamespace + content.text` in the service's translations
/// (read from the environment by `ListTagCloud`), returning the translation's display text and
/// value image.
enum ListTagTranslation {
    static func display(of content: GalleryTag.Content, translates: Bool) -> (text: String, imageURL: URL?) {
        (content.text, nil)
    }
}
