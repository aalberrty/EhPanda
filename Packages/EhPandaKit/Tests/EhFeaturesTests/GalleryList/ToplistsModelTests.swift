@testable import EhFeatures
import EhModels
import EhTestSupport
import Testing

@Suite struct ToplistsModelTests {
    @Test func toplistsPageByNumber() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.toplists))
        let model = env.make { ToplistsModel() }

        await model.list.loadIfNeeded()
        #expect(env.query("tl", ofRequest: 0) == "15")
        #expect(env.query("p", ofRequest: 0) == nil)
        #expect(model.list.pageNumber.current == 0)
        #expect(model.list.pageNumber.maximum > 0)
        #expect(model.list.hasNextPage)
        #expect(model.list.canJumpPage)

        await model.list.loadMore()
        #expect(env.query("p", ofRequest: 1) == "1")
        #expect(env.transport.requests[1].url?.host == "e-hentai.org")
    }

    @Test func jumpPageAcceptsOnlyExistingPages() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.toplists))
        let model = env.make { ToplistsModel() }
        await model.list.loadIfNeeded()
        let maximum = model.list.maximumPage

        model.presentJumpPage()
        #expect(model.isJumpPagePresented)
        for input in ["", "abc", "0", "-1", String(maximum + 1)] {
            model.jumpPageText = input
            #expect(!model.confirmJumpPage())
        }
        #expect(model.isJumpPagePresented)
        #expect(!model.list.galleries.isEmpty)

        model.jumpPageText = "2"
        #expect(model.confirmJumpPage())
        #expect(!model.isJumpPagePresented)
        #expect(model.list.galleries.isEmpty)
        await model.list.loadIfNeeded()
        #expect(env.query("p", ofRequest: 1) == "1")
        #expect(model.list.phase == .content)
    }

    @Test func eachPeriodKeepsItsOwnList() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.toplists))
        let model = env.make { ToplistsModel() }
        var screen = ListScreenTask()
        await screen.render(model.list)
        let yesterday = model.list
        model.titleFilter = "a"

        // Selecting a period that has not loaded loads it, through the view's task alone.
        model.select(.allTime)
        #expect(model.list !== yesterday)
        #expect(model.list.source == .toplists(.allTime))
        #expect(model.list.titleFilter == "a")
        await screen.render(model.list)
        #expect(env.query("tl", ofRequest: 1) == "11")
        #expect(model.list.phase == .content)

        model.select(.pastMonth)
        await screen.render(model.list)
        #expect(env.transport.requests.count == 3)
        #expect(model.list.phase == .content)

        // Switching back shows the loaded list without another request.
        model.select(.yesterday)
        #expect(model.list === yesterday)
        await screen.render(model.list)
        #expect(env.transport.requests.count == 3)
        #expect(model.list.phase == .content)
    }

    @Test func singlePageCannotJump() {
        let model = GalleryListModel(source: .frontpage)
        #expect(!model.canJumpPage)
        #expect(!model.jumpToPage("1"))
    }
}
