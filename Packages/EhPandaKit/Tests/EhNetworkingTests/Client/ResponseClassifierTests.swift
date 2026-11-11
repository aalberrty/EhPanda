@testable import EhNetworking
import EhModels
import EhTestSupport
import Foundation
import Testing

struct ResponseClassifierTests {
    // MARK: Before parsing

    @Test func emptyExhentaiPageIsARefusedSession() {
        let response = snapshot("https://exhentai.org/favorites.php", body: Data())

        #expect(ResponseClassifier.classifyBeforeParsing(response) == .exhentaiAccessDenied)
        #expect(ResponseClassifier.classifyParseFailure(response) == .exhentaiAccessDenied)
    }

    @Test func exhentaiImageIsARefusedSession() {
        let response = snapshot("https://exhentai.org/", contentType: "image/gif", body: Data([0x47, 0x49, 0x46]))

        #expect(ResponseClassifier.classifyBeforeParsing(response) == .exhentaiAccessDenied)
    }

    @Test func emptyEhentaiPageIsNotRecognised() {
        let response = snapshot("https://e-hentai.org/", body: Data())

        #expect(ResponseClassifier.classifyBeforeParsing(response) == nil)
        #expect(ResponseClassifier.classifyParseFailure(response) == nil)
    }

    @Test func emptyExhentaiErrorIsAServerErrorNotARefusal() {
        let response = snapshot("https://exhentai.org/", status: 502, body: Data())

        #expect(ResponseClassifier.classifyBeforeParsing(response) == nil)
        #expect(ResponseClassifier.classifyParseFailure(response) == .serverError(502))
    }

    @Test func redirectToTheLoginBounceIsLoginRequired() throws {
        let response = snapshot(
            "https://e-hentai.org/favorites.php", responseURL: "https://e-hentai.org/bounce_login.php?b=d&bt=1-6",
            body: try Fixture.data(ClientFixture.loginRequired)
        )

        #expect(ResponseClassifier.classifyBeforeParsing(response) == .loginRequired)
    }

    @Test func loginPromptWithoutRedirectIsLoginRequired() throws {
        let response = snapshot("https://e-hentai.org/uconfig.php", body: try Fixture.data(ClientFixture.loginRequired))

        #expect(ResponseClassifier.classifyBeforeParsing(response) == .loginRequired)
    }

    @Test func largePageThatQuotesTheLoginPromptIsNotOne() {
        let filler = String(repeating: "<p>comment</p>", count: 1000)
        let body = Data("<p>This page requires you to log on.</p>\(filler)".utf8)
        let response = snapshot("https://e-hentai.org/g/1/a/", body: body)

        #expect(ResponseClassifier.classifyBeforeParsing(response) == nil)
        #expect(ResponseClassifier.classifyParseFailure(response) == nil)
    }

    @Test func normalPagesAreUnaffected() throws {
        for (url, fixture) in [
            ("https://e-hentai.org/", ClientFixture.list("FrontPageCompactList")),
            ("https://exhentai.org/favorites.php", ClientFixture.list("FavoritesCompactList")),
            ("https://e-hentai.org/uconfig.php", ClientFixture.ehSetting),
            ("https://e-hentai.org/g/3103480/0000000000/", ClientFixture.detail)
        ] {
            let response = snapshot(url, body: try Fixture.data(fixture))
            #expect(ResponseClassifier.classifyBeforeParsing(response) == nil, "\(fixture)")
            #expect(ResponseClassifier.classifyParseFailure(response) == nil, "\(fixture)")
        }
    }

    // MARK: After a parse failure

    @Test func banPageIsAnIPBan() throws {
        let response = snapshot("https://e-hentai.org/uconfig.php", body: try Fixture.data(ClientFixture.ipBanned))

        #expect(ResponseClassifier.classifyBeforeParsing(response) == nil)
        #expect(ResponseClassifier.classifyParseFailure(response) == .ipBanned(.minutes(59, seconds: 48)))
    }

    @Test func banInMarkupEndsAtTheTag() {
        let body = "<html><body>Your IP address has been temporarily banned. "
            + "The ban expires in 2 days and 3 hours</body></html>"
        let response = snapshot("https://exhentai.org/", body: Data(body.utf8))

        #expect(ResponseClassifier.classifyParseFailure(response) == .ipBanned(.days(2, hours: 3)))
    }

    @Test(arguments: [500, 502, 503, 403, 404, 429])
    func errorStatusWithAnUnreadableBodyIsAServerError(status: Int) {
        let response = snapshot("https://e-hentai.org/", status: status, body: Data("<html>Bad Gateway</html>".utf8))

        #expect(ResponseClassifier.classifyBeforeParsing(response) == nil)
        #expect(ResponseClassifier.classifyParseFailure(response) == .serverError(status))
    }

    @Test func unknownPageStaysUnrecognised() {
        let response = snapshot("https://e-hentai.org/", body: Data("<html><body>Something new</body></html>".utf8))

        #expect(ResponseClassifier.classifyParseFailure(response) == nil)
    }

    // MARK: Log description

    @Test func logDescriptionNamesHostPathAndQueryNamesOnly() {
        var request = URLRequest(url: URL(string: "https://e-hentai.org/favorites.php?favcat=all&f_search=secret")!)
        request.setValue("ipb_member_id=4242; ipb_pass_hash=cafe", forHTTPHeaderField: "Cookie")
        let response = HTTPResponse(
            data: Data(repeating: 0x20, count: 1307),
            response: HTTPURLResponse(
                url: URL(string: "https://e-hentai.org/bounce_login.php?b=d&bt=1-6")!, statusCode: 200,
                httpVersion: nil, headerFields: ["Content-Type": "text/html; charset=UTF-8", "Set-Cookie": "a=b"]
            )!
        )

        let text = ResponseSnapshot(request: request, response: response).logDescription

        #expect(text == "GET e-hentai.org/favorites.php?favcat&f_search → e-hentai.org/bounce_login.php, "
            + "status 200, text/html, 1307 bytes")
    }

    // MARK: Helpers

    private func snapshot(
        _ url: String, status: Int = 200, contentType: String? = "text/html; charset=UTF-8",
        responseURL: String? = nil, body: Data
    ) -> ResponseSnapshot {
        let request = URLRequest(url: clientURL(url))
        let headers = contentType.map { ["Content-Type": $0] } ?? [:]
        let response = HTTPURLResponse(
            url: clientURL(responseURL ?? url), statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
        )
        return ResponseSnapshot(request: request, response: HTTPResponse(data: body, response: response!))
    }
}
