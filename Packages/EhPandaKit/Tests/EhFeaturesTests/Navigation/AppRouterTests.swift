import EhFeatures
import EhModels
import Foundation
import Testing

@Suite struct AppRouterTests {
    private func makeGallery(gid: String = "1") -> Gallery {
        Gallery(
            gid: gid, token: "t", title: "Title", rating: 4, tags: [], category: .doujinshi,
            uploader: nil, pageCount: 1, postedDate: Date(timeIntervalSince1970: 0),
            coverURL: nil, galleryURL: nil
        )
    }

    @Test func selectingAnotherTabOnlySwitches() {
        let router = AppRouter()
        router.home.push(.galleryList(.popular))

        router.select(.search)

        #expect(router.selectedTab == .search)
        #expect(router.home.path == [.galleryList(.popular)])
        #expect(router.rootReselectionCount(for: .search) == 0)
    }

    @Test func reselectingATabWithPushedScreensPopsToRoot() {
        let router = AppRouter()
        router.home.push(.galleryList(.popular))
        router.home.push(.search(keyword: "language:english"))

        router.select(.home)

        #expect(router.home.isAtRoot)
        #expect(router.rootReselectionCount(for: .home) == 0)
    }

    @Test func reselectingATabPopsChildScreensAndSearchesInOneTap() {
        let router = AppRouter()
        let gallery = makeGallery()
        router.select(.search)
        router.search.push(.typedSearch(keyword: "a"))
        router.search.push(.detail(gallery))
        router.search.push(.detailChild(DetailChildRoute(
            parent: GalleryDetailModel(gallery: gallery), destination: .comments(scrollTo: nil)
        )))

        router.select(.search)

        #expect(router.search.isAtRoot)
        #expect(router.rootReselectionCount(for: .search) == 0)
    }

    @Test func reselectingATabAtItsRootBumpsTheCounter() {
        let router = AppRouter()

        router.select(.home)
        router.select(.home)

        #expect(router.rootReselectionCount(for: .home) == 2)
        #expect(router.rootReselectionCount(for: .library) == 0)
    }

    @Test func presentingAGalleryStartsWithAnEmptyStack() {
        let router = AppRouter()
        router.present(makeGallery(gid: "1"))
        router.presented.push(.search(keyword: "a"))

        router.present(makeGallery(gid: "2"))

        #expect(router.presentedGallery?.gid == "2")
        #expect(router.presented.isAtRoot)

        router.dismissPresentedGallery()
        #expect(router.presentedGallery == nil)
    }

    @Test func stackRouterPushAndPop() {
        let stack = StackRouter()
        stack.push(.settings(.account))
        stack.push(.settings(.login))
        stack.pop()
        #expect(stack.path == [.settings(.account)])
        stack.popToRoot()
        #expect(stack.isAtRoot)
    }
}
