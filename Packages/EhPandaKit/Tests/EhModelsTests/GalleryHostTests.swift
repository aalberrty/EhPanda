import EhModels
import EhTestSupport
import Testing

@Test func galleryHostURLs() {
    #expect(GalleryHost.ehentai.url.host() == "e-hentai.org")
    #expect(GalleryHost.exhentai.cookieURLs.count == 2)
}

@Test func missingFixtureThrows() {
    #expect(throws: Fixture.FixtureError.self) { try Fixture.data("does-not-exist") }
}
