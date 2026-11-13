import EhFeatures
import EhModels
import Foundation
import Testing

@Suite struct TabBarVisibilityTests {
    private func makeGallery(gid: String) -> Gallery {
        Gallery(
            gid: gid, token: "t", title: "Title", rating: 4, tags: [], category: .doujinshi,
            uploader: nil, pageCount: 1, postedDate: Date(timeIntervalSince1970: 0),
            coverURL: nil, galleryURL: nil
        )
    }

    /// The visibility each screen of `stack` states, bottom to top.
    private func visibilities(_ stack: StackRouter) -> [TabBarVisibility] {
        stack.path.map(stack.tabBarVisibility(for:))
    }

    @Test func aGalleryAndTheScreensPushedFromItHideTheTabBar() {
        let gallery = makeGallery(gid: "1")
        let child = DetailChildRoute(parent: GalleryDetailModel(gallery: gallery), destination: .galleryInfos)

        #expect(Route.detail(gallery).hidesTabBar)
        #expect(Route.detail(gallery, intent: .read(page: 2)).hidesTabBar)
        #expect(Route.detailChild(child).hidesTabBar)
        #expect(!Route.galleryList(.popular).hidesTabBar)
        #expect(!Route.search(keyword: "a").hidesTabBar)
        #expect(!Route.typedSearch(keyword: "a").hidesTabBar)
        #expect(!Route.settings(.general).hidesTabBar)
    }

    @Test func onlyTheTopScreenStatesTheTabBarAtAnyDepth() {
        let first = makeGallery(gid: "1")
        let second = makeGallery(gid: "2")
        let infos = DetailChildRoute(parent: GalleryDetailModel(gallery: second), destination: .galleryInfos)
        let stack = StackRouter()

        stack.push(.galleryList(.frontpage))
        #expect(visibilities(stack) == [.visible])
        stack.push(.detail(first))
        #expect(visibilities(stack) == [.automatic, .hidden])
        // A tag, the uploader or similar galleries: a search above the gallery shows the bar.
        stack.push(.search(keyword: "artist:a"))
        #expect(visibilities(stack) == [.automatic, .automatic, .visible])
        stack.push(.detail(second))
        #expect(visibilities(stack) == [.automatic, .automatic, .automatic, .hidden])
        stack.push(.detailChild(infos))
        #expect(visibilities(stack) == [.automatic, .automatic, .automatic, .automatic, .hidden])

        stack.pop()
        #expect(visibilities(stack) == [.automatic, .automatic, .automatic, .hidden])
        stack.pop()
        #expect(visibilities(stack) == [.automatic, .automatic, .visible])
        stack.pop()
        #expect(visibilities(stack) == [.automatic, .hidden])
        stack.pop()
        #expect(visibilities(stack) == [.visible])
    }

    @Test func screensPoppedToTheRootNoLongerStateAnything() {
        let gallery = makeGallery(gid: "1")
        let stack = StackRouter()
        stack.push(.detail(gallery))
        stack.push(.search(keyword: "a"))

        stack.popToRoot()

        #expect(stack.tabBarVisibility(for: .detail(gallery)) == .automatic)
        #expect(stack.tabBarVisibility(for: .search(keyword: "a")) == .automatic)
    }

    @Test func aRouteEqualToTheTopOneStatesTheSameAsTheTop() {
        let gallery = makeGallery(gid: "1")
        let stack = StackRouter()

        stack.push(.detail(gallery))
        stack.push(.search(keyword: "a"))
        stack.push(.detail(gallery))

        #expect(visibilities(stack) == [.hidden, .automatic, .hidden])
    }

    @Test func eachStackFollowsItsOwnTopScreen() {
        let router = AppRouter()
        router.home.push(.detail(makeGallery(gid: "1")))
        router.library.push(.search(keyword: "a"))

        #expect(visibilities(router.home) == [.hidden])
        #expect(visibilities(router.library) == [.visible])
    }
}
