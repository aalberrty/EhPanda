import EhFeatures
import EhModels
import SwiftUI

/// The gallery detail screen, for `Route.detail` and for galleries opened from links.
/// `intent` is what the screen does once it has opened (open the reader or the comments).
struct GalleryDetailDestination: View {
    let gallery: Gallery

    @State private var model: GalleryDetailModel

    init(gallery: Gallery, intent: DetailIntent? = nil) {
        self.gallery = gallery
        _model = State(initialValue: GalleryDetailModel(gallery: gallery, intent: intent))
    }

    var body: some View {
        GalleryDetailView(model: model)
    }
}

/// `Route.detailChild`: a screen pushed from a gallery's detail screen.
struct GalleryDetailChildDestination: View {
    let route: DetailChildRoute

    var body: some View {
        let model = route.parent
        switch route.destination {
        case .comments(let commentID):
            CommentsScreen(detail: model, scrollTo: commentID)
        case .previews:
            PreviewsGridScreen(
                gallery: model.gallery, detail: model.detail, pageCount: model.pageCount,
                config: model.previewConfig, previewURLs: model.previewURLs
            )
        case .galleryInfos:
            if let detail = model.detail {
                GalleryInfosScreen(gallery: model.gallery, detail: detail)
            }
        case .archives, .torrents, .postComment, .tagDetail, .reader:
            EmptyView()
        }
    }
}
