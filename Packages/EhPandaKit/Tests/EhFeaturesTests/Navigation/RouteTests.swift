import EhFeatures
import EhModels
import Foundation
import Testing

@MainActor
@Suite struct RouteTests {
    private func makeGallery(gid: String = "1") -> Gallery {
        Gallery(
            gid: gid, token: "t", title: "Title", rating: 4, tags: [], category: .doujinshi,
            uploader: nil, pageCount: 1, postedDate: Date(timeIntervalSince1970: 0),
            coverURL: nil, galleryURL: nil
        )
    }

    @Test func detailRoutesDefaultToNoIntent() {
        let gallery = makeGallery()
        #expect(Route.detail(gallery) == .detail(gallery, intent: nil))
        #expect(Route.detail(gallery) != .detail(gallery, intent: .read(page: 2)))
        #expect(Route.detail(gallery, intent: .read(page: 2)) != .detail(gallery, intent: .read(page: 3)))
    }

    @Test func typedAndDetailSearchesAreDifferentRoutes() {
        #expect(Route.typedSearch(keyword: "a") != .search(keyword: "a"))
        #expect(Route.typedSearch(keyword: "a") == .typedSearch(keyword: "a"))
    }

    @Test func detailChildRoutesCompareTheModelByIdentity() {
        let gallery = makeGallery()
        let parent = GalleryDetailModel(gallery: gallery)
        let otherParent = GalleryDetailModel(gallery: gallery)

        let comments = DetailChildRoute(parent: parent, destination: .comments(scrollTo: nil))
        #expect(comments == DetailChildRoute(parent: parent, destination: .comments(scrollTo: nil)))
        #expect(comments.hashValue == DetailChildRoute(parent: parent, destination: .comments(scrollTo: nil)).hashValue)
        // Same gallery, another screen's model.
        #expect(comments != DetailChildRoute(parent: otherParent, destination: .comments(scrollTo: nil)))
        #expect(comments != DetailChildRoute(parent: parent, destination: .previews))
        #expect(comments != DetailChildRoute(parent: parent, destination: .comments(scrollTo: "1")))
        #expect(Set([comments, comments, DetailChildRoute(parent: otherParent, destination: .previews)]).count == 2)
    }

    @Test func childRoutesSitInThePathAboveTheirDetail() {
        let gallery = makeGallery()
        let parent = GalleryDetailModel(gallery: gallery)
        let stack = StackRouter()

        stack.push(.detail(gallery))
        stack.push(.detailChild(DetailChildRoute(parent: parent, destination: .galleryInfos)))
        stack.push(.search(keyword: "a"))
        stack.pop()

        #expect(stack.path == [
            .detail(gallery), .detailChild(DetailChildRoute(parent: parent, destination: .galleryInfos))
        ])
    }

    @Test func linkTargetsMapToDetailIntents() {
        #expect(DetailIntent(GalleryLinkTarget.page(7)) == .read(page: 7))
        #expect(DetailIntent(GalleryLinkTarget.comment("4242")) == .comments(scrollTo: "4242"))
    }
}
