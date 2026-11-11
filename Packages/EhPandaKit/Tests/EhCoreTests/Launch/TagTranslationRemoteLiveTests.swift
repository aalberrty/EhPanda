@testable import EhCore
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@Suite struct TagTranslationRemoteLiveTests {
    private let transport = StubTransport()

    private var remote: TagTranslationRemote {
        .client(EhClient(transport: transport, cookies: CookieStore(storage: InMemoryCookieStorage()), host: { .ehentai }))
    }

    @Test func newerReleaseReturnsItsDate() async throws {
        transport.on(.any, reply: .body(Data(#"{"published_at":"2024-01-02T03:04:05Z"}"#.utf8)))

        let date = try await remote.latestReleaseDate(.english, .distantPast)

        #expect(date == Date(timeIntervalSince1970: 1_704_164_645))
    }

    @Test func noNewerReleaseReturnsTheStoredDate() async throws {
        transport.on(.any, reply: .body(Data(#"{"published_at":"2024-01-02T03:04:05Z"}"#.utf8)))
        let stored = Date(timeIntervalSince1970: 1_704_164_645)

        let date = try await remote.latestReleaseDate(.english, stored)

        #expect(date == stored)
    }

    @Test func networkFailureIsReported() async {
        transport.on(.any, reply: .error(URLError(.timedOut)))

        await #expect(throws: AppError.networkingFailed) {
            try await remote.latestReleaseDate(.english, .distantPast)
        }
    }

    @Test func downloadDecodesTheDatabase() async throws {
        transport.on(.any, reply: .body(Data("""
        {"data":[{"namespace":"female","data":{"big breasts":{"name":"巨乳","intro":"Large.","links":""}}}]}
        """.utf8)))

        let translations = try await remote.downloadDatabase(.simplifiedChinese)

        #expect(translations["femalebig breasts"]?.value == "巨乳")
    }
}
