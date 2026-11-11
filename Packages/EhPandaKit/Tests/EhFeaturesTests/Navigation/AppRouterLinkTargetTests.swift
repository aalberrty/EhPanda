import EhFeatures
import EhModels
import Foundation
import Testing

@Suite struct AppRouterLinkTargetTests {
    private func makeGallery(gid: String) -> Gallery {
        Gallery(
            gid: gid, token: "t", title: "Title", rating: 4, tags: [], category: .doujinshi,
            pageCount: 1, postedDate: Date(timeIntervalSince1970: 0), coverURL: nil, galleryURL: nil
        )
    }

    @Test func presentingWithoutATargetHasNone() {
        let router = AppRouter()

        router.present(makeGallery(gid: "1"))

        #expect(router.presentedGalleryTarget == nil)
        #expect(router.takePresentedGalleryTarget(for: "1") == nil)
    }

    @Test func targetIsTakenOnceByThePresentedGallery() {
        let router = AppRouter()
        router.present(makeGallery(gid: "1"), target: .page(5))

        #expect(router.takePresentedGalleryTarget(for: "2") == nil)
        #expect(router.takePresentedGalleryTarget(for: "1") == .page(5))
        #expect(router.takePresentedGalleryTarget(for: "1") == nil)
        #expect(router.presentedGallery?.gid == "1")
    }

    @Test func dismissingForgetsTheTarget() {
        let router = AppRouter()
        router.present(makeGallery(gid: "1"), target: .comment("42"))

        router.dismissPresentedGallery()

        #expect(router.presentedGalleryTarget == nil)
    }

    @Test func presentingAgainReplacesTheTarget() {
        let router = AppRouter()
        router.present(makeGallery(gid: "1"), target: .comment("42"))

        router.present(makeGallery(gid: "2"))

        #expect(router.presentedGalleryTarget == nil)
    }
}
