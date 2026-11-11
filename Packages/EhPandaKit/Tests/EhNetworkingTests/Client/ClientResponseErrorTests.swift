import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

/// Responses that are not the page an operation asked for, through real client operations.
struct ClientResponseErrorTests {
    // MARK: ExHentai refused the session

    @Test func frontpageOnExhentaiWithAnEmptyBody() async {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .html("", headers: ["Content-Type": "text/html; charset=UTF-8"]))

        let error = await thrownError { try await harness.client.frontpage(filter: Filter()) }

        #expect(error as? AppError == .exhentaiAccessDenied)
    }

    @Test func favoritesOnExhentaiWithAnEmptyBodyIsNotAnEmptyList() async {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .status(200))

        let error = await thrownError { try await harness.client.favorites(category: -1) }

        #expect(error as? AppError == .exhentaiAccessDenied)
    }

    @Test func favoriteCategoriesOnExhentaiWithAnEmptyBody() async {
        // The owner's report: this logged only `parseFailed`.
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .status(200, headers: ["Content-Type": "text/html; charset=UTF-8"]))

        let error = await thrownError { try await harness.client.favoriteCategories() }

        #expect(error as? AppError == .exhentaiAccessDenied)
        #expect(harness.failures.all.count == 1)
        #expect(harness.failures.all.first?.description == "favoriteCategories() failed: exhentaiAccessDenied "
            + "(recognised before parsing); GET exhentai.org/uconfig.php, status 200, text/html, 0 bytes")
    }

    @Test func exhentaiRedirectLoopWithoutCookies() async {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .error(URLError(.httpTooManyRedirects)))

        let error = await thrownError { try await harness.client.frontpage(filter: Filter()) }

        #expect(error as? AppError == .exhentaiAccessDenied)
        #expect(harness.failures.all.map(\.description) == [
            "frontpage(filter:after:) failed: exhentaiAccessDenied (redirect loop); GET exhentai.org/"
        ])
    }

    @Test func redirectLoopElsewhereIsANetworkError() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .error(URLError(.httpTooManyRedirects)))

        let error = await thrownError { try await harness.client.frontpage(filter: Filter()) }

        #expect(error as? AppError == .networkingFailed)
        #expect(harness.failures.all.isEmpty)
    }

    @Test func fetchingIgneousStillIgnoresTheBody() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .status(200))

        try await harness.client.fetchIgneous()
    }

    // MARK: Login required

    @Test func favoritesRedirectedToTheLoginPage() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .handler { _ in
            try HTTPResponse(
                data: Fixture.data(ClientFixture.loginRequired),
                response: #require(HTTPURLResponse(
                    url: clientURL("https://e-hentai.org/bounce_login.php?b=d&bt=1-6"), statusCode: 200,
                    httpVersion: nil, headerFields: ["Content-Type": "text/html; charset=UTF-8"]
                ))
            )
        })

        let error = await thrownError { try await harness.client.favorites(category: -1) }

        #expect(error as? AppError == .loginRequired)
        #expect(harness.failures.all.first?.description.contains("e-hentai.org/favorites.php?favcat → "
            + "e-hentai.org/bounce_login.php, status 200, text/html, 1307 bytes") == true)
    }

    @Test func settingsAnsweredWithTheLoginPrompt() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.loginRequired))

        let error = await thrownError { try await harness.client.ehSetting() }

        #expect(error as? AppError == .loginRequired)
    }

    // MARK: IP ban

    @Test func banOnAnOperationWhoseParserDoesNotKnowIt() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ipBanned))

        let error = await thrownError { try await harness.client.favoriteCategories() }

        #expect(error as? AppError == .ipBanned(.minutes(59, seconds: 48)))
        #expect(harness.failures.all.first?.description
            .hasPrefix("favoriteCategories() failed: ipBanned") == true)
    }

    @Test func banOnAListIsStillReportedByItsParser() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ipBanned))

        let error = await thrownError { try await harness.client.frontpage(filter: Filter()) }

        #expect(error as? AppError == .ipBanned(.minutes(59, seconds: 48)))
    }

    // MARK: Server errors

    @Test func serverErrorPage() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html("<html><body>502 Bad Gateway</body></html>", status: 502))

        let error = await thrownError { try await harness.client.ehSetting() }

        #expect(error as? AppError == .serverError(502))
    }

    @Test func readablePageWithAnErrorStatusIsStillRead() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.detail, status: 404))

        let detail = try await harness.client.galleryDetail(
            gid: "3103480", galleryURL: clientURL("https://e-hentai.org/g/3103480/0000000000/")
        )

        #expect(detail.detail.gid == "3103480")
        #expect(harness.failures.all.isEmpty)
    }

    @Test func removedGalleryKeepsItsSpecificError() async {
        let harness = ClientHarness()
        let notice = #"<html><body><div class="d"><p>This gallery has been removed or is unavailable.</p>"#
            + "</div></body></html>"
        harness.transport.on(.any, reply: .html(notice, status: 404))

        let error = await thrownError {
            try await harness.client.galleryDetail(gid: "1", galleryURL: clientURL("https://e-hentai.org/g/1/a/"))
        }

        #expect(error as? AppError == .expunged("This gallery has been removed or is unavailable."))
    }

    // MARK: Unrecognised and normal responses

    @Test func unknownPageStaysAParseFailureAndIsLogged() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html("<html><body>Something new</body></html>"))

        let error = await thrownError { try await harness.client.ehSetting() }

        #expect(error as? AppError == .parseFailed)
        #expect(harness.failures.all.map(\.description) == [
            "ehSetting() failed: parseFailed (unrecognised response); GET e-hentai.org/uconfig.php, "
                + "status 200, no content type, 39 bytes"
        ])
    }

    @Test func normalPageOnExhentaiIsUnaffected() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .fixture(ClientFixture.list("FrontPageCompactList")))

        let page = try await harness.client.frontpage(filter: Filter())

        #expect(!page.galleries.isEmpty)
        #expect(harness.failures.all.isEmpty)
    }

    @Test func networkFailuresAreNotLogged() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .error(URLError(.timedOut)))

        _ = await thrownError { try await harness.client.ehSetting() }

        #expect(harness.failures.all.isEmpty)
    }

    @Test func cancellationAfterARefusedSessionIsStillCancellation() async {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .status(200))

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await harness.client.frontpage(filter: Filter())
        }
        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
        #expect(harness.failures.all.isEmpty)
    }
}
