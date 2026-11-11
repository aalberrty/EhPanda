import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

struct OperationClientTests {
    private let galleryURL = clientURL("https://e-hentai.org/g/3103480/0000000000/")

    @Test func addFavoriteIgnoresTheResponseBody() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html("<html>anything</html>"))

        try await harness.client.addFavorite(gid: "1", token: "t", category: 4)

        let request = try harness.onlyRequest()
        let expected = harness.builder.favorGallery(gid: "1", token: "t", favIndex: 4)
        #expect(line(request) == "POST \(expected.url?.absoluteString ?? "")")
        #expect(request.httpBody == expected.httpBody)
    }

    @Test func removeFavorite() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .status(500))

        try await harness.client.removeFavorite(gid: "1")

        let request = try harness.onlyRequest()
        #expect(line(request) == "POST https://exhentai.org/favorites.php")
        #expect(request.httpBody == harness.builder.unfavorGallery(gid: "1").httpBody)
    }

    @Test func rateSendsTheMemberIDOfTheCurrentHost() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.logIn(memberID: "111", host: .ehentai)
        harness.logIn(memberID: "222", host: .exhentai)
        harness.transport.on(.any, reply: .status(200))

        try await harness.client.rate(gid: "3103480", token: "tok", apiKey: "key", rating: 7)

        let request = try harness.onlyRequest()
        #expect(line(request) == "POST https://exhentai.org/api.php")
        let body = try jsonBody(request)
        #expect(body["method"] as? String == "rategallery")
        #expect(body["apiuid"] as? Int == 222)
        #expect(body["apikey"] as? String == "key")
        #expect(body["gid"] as? Int == 3103480)
        #expect(body["token"] as? String == "tok")
        #expect(body["rating"] as? Int == 7)
    }

    @Test func rateWithoutLoginSendsNothing() async throws {
        let harness = ClientHarness()

        let error = await thrownError {
            try await harness.client.rate(gid: "1", token: "t", apiKey: "k", rating: 10)
        }

        #expect(error as? AppError == .unknown)
        #expect(harness.requests.isEmpty)
    }

    @Test func postAndEditComment() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .status(200))

        try await harness.client.postComment("Hi\nthere", galleryURL: galleryURL)
        try await harness.client.editComment(id: "99", content: "Edited", galleryURL: galleryURL)

        let requests = harness.requests
        #expect(requests.map(line) == [
            "POST \(galleryURL.absoluteString)",
            "POST \(galleryURL.absoluteString)"
        ])
        #expect(requests.first?.httpBody == harness.builder.commentGallery(content: "Hi\nthere", galleryURL: galleryURL).httpBody)
        #expect(requests.last?.httpBody == harness.builder.editGalleryComment(
            commentID: "99", content: "Edited", galleryURL: galleryURL
        ).httpBody)
    }

    @Test func voteComment() async throws {
        let harness = ClientHarness()
        harness.logIn(memberID: "111")
        harness.transport.on(.any, reply: .status(200))

        try await harness.client.voteComment(gid: "1", token: "t", commentID: "55", apiKey: "k", vote: -1)

        let body = try jsonBody(try harness.onlyRequest())
        #expect(body["method"] as? String == "votecomment")
        #expect(body["apiuid"] as? Int == 111)
        #expect(body["comment_id"] as? Int == 55)
        #expect(body["comment_vote"] as? Int == -1)
    }

    @Test func voteTag() async throws {
        let harness = ClientHarness()
        harness.logIn(memberID: "111")
        harness.transport.on(.any, reply: .status(200))

        try await harness.client.voteTag(gid: "1", token: "t", tag: "female:glasses", apiKey: "k", vote: 1)

        let request = try harness.onlyRequest()
        #expect(line(request) == "POST https://e-hentai.org/api.php")
        let body = try jsonBody(request)
        #expect(body["method"] as? String == "taggallery")
        #expect(body["tags"] as? String == "female:glasses")
        #expect(body["vote"] as? Int == 1)
    }

    @Test func mutatingOperationSurfacesTransportFailure() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .error(URLError(.timedOut)))

        let error = await thrownError { try await harness.client.postComment("Hi", galleryURL: galleryURL) }

        #expect(error as? AppError == .networkingFailed)
    }
}

struct TagTranslationClientTests {
    @Test func releaseDate() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .body(Data(#"{"published_at":"2024-01-02T03:04:05Z"}"#.utf8)))

        let date = try await harness.client.tagTranslationReleaseDate(language: .japanese, after: .distantPast)

        #expect(line(try harness.onlyRequest())
            == "GET https://api.github.com/repos/EhPanda-Team/EhTagTranslation_Database_JPN/releases/latest")
        #expect(date == Date(timeIntervalSince1970: 1_704_164_645))
    }

    @Test func noNewerRelease() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .body(Data(#"{"published_at":"2024-01-02T03:04:05Z"}"#.utf8)))

        let error = await thrownError {
            try await harness.client.tagTranslationReleaseDate(
                language: .english, after: Date(timeIntervalSince1970: 1_704_164_645)
            )
        }

        #expect(error as? AppError == .noUpdates)
    }

    @Test func translations() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .body(Data("""
        {"data":[{"namespace":"female","data":{"big breasts":{"name":"巨乳","intro":"Large.","links":""}}}]}
        """.utf8)))

        let translations = try await harness.client.tagTranslations(language: .simplifiedChinese)

        #expect(line(try harness.onlyRequest())
            == "GET https://github.com/EhTagTranslation/Database/releases/latest/download/db.raw.json")
        #expect(translations["femalebig breasts"]?.value == "巨乳")
    }

    @Test func unreadableNotFoundPageIsAServerError() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .response(status: 404, body: Data("Not Found".utf8)))

        let error = await thrownError { try await harness.client.tagTranslations(language: .english) }

        #expect(error as? AppError == .serverError(404))
    }

    @Test func unreadableReleaseWithASuccessStatusIsAParseFailure() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .body(Data("not json".utf8)))

        let error = await thrownError { try await harness.client.tagTranslations(language: .english) }

        #expect(error as? AppError == .parseFailed)
    }
}
