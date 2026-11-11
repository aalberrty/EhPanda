import EhNetworking
import EhTestSupport
import Foundation
import Testing

struct StubTransportTests {
    let stub = StubTransport()

    @Test func matchesOnPathHostMethodAndQuery() async throws {
        stub.on(.path("/g/1/abc/"), reply: .html("gallery"))
        stub.on(.method("POST") && .host("e-hentai.org"), reply: .html("post"))
        stub.on(.query("page", "2"), reply: .html("page 2"))
        stub.on(.query("f_search"), reply: .html("search"))

        func body(_ request: URLRequest) async throws -> String {
            String(decoding: try await stub.send(request).data, as: UTF8.self)
        }
        #expect(try await body(makeRequest("https://e-hentai.org/g/1/abc/")) == "gallery")
        #expect(try await body(makeRequest("https://e-hentai.org/x", method: "post")) == "post")
        #expect(try await body(makeRequest("https://e-hentai.org/?page=2")) == "page 2")
        #expect(try await body(makeRequest("https://e-hentai.org/?f_search=a")) == "search")
    }

    @Test func latestMatchingRouteWins() async throws {
        stub.on(.any, reply: .status(200))
        stub.on(.host("exhentai.org"), reply: .status(404))

        #expect(try await stub.send(makeRequest("https://exhentai.org/")).statusCode == 404)
        #expect(try await stub.send(makeRequest("https://e-hentai.org/")).statusCode == 200)
    }

    @Test func returnsStatusHeadersAndBody() async throws {
        stub.on(.any, reply: .response(status: 302, headers: ["Location": "/x"], body: Data("b".utf8)))

        let response = try await stub.send(makeRequest("https://e-hentai.org/a"))

        #expect(response.statusCode == 302)
        #expect(response.response.value(forHTTPHeaderField: "Location") == "/x")
        #expect(response.response.url?.absoluteString == "https://e-hentai.org/a")
        #expect(response.data == Data("b".utf8))
    }

    @Test func loadsFixtures() async throws {
        stub.on(.any, reply: .fixture("README.md", status: 201))

        let response = try await stub.send(makeRequest())

        #expect(response.statusCode == 201)
        #expect(response.data == (try Fixture.data("README.md")))
    }

    @Test func missingFixtureThrows() async {
        stub.on(.any, reply: .fixture("Nope/missing.html"))
        await #expect(throws: Fixture.FixtureError.self) { try await stub.send(makeRequest()) }
    }

    @Test func scriptedSequenceRepeatsItsLastReply() async throws {
        stub.on(.any, replies: .error(URLError(.timedOut)), .status(500), .status(200))

        await #expect(throws: URLError(.timedOut)) { try await stub.send(makeRequest()) }
        #expect(try await stub.send(makeRequest()).statusCode == 500)
        #expect(try await stub.send(makeRequest()).statusCode == 200)
        #expect(try await stub.send(makeRequest()).statusCode == 200)
    }

    @Test func recordsRequestsInOrderIncludingUnmatched() async throws {
        stub.on(.path("/a"), reply: .status(200))

        _ = try await stub.send(makeRequest("https://e-hentai.org/a"))
        await #expect(throws: StubTransport.Unmatched.self) {
            try await stub.send(makeRequest("https://e-hentai.org/b", method: "POST"))
        }

        #expect(stub.requests.map { $0.url?.path } == ["/a", "/b"])
        #expect(stub.requests.map(\.httpMethod) == ["GET", "POST"])

        stub.reset()
        #expect(stub.requests.isEmpty)
        await #expect(throws: StubTransport.Unmatched.self) { try await stub.send(makeRequest("https://e-hentai.org/a")) }
    }

    @Test func handlerComputesTheResponse() async throws {
        stub.on(.any, reply: .handler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return HTTPResponse(data: Data(), response: response)
        })
        #expect(try await stub.send(makeRequest()).statusCode == 204)
    }

    @Test func isSafeUnderConcurrentUse() async throws {
        stub.on(.any, reply: .status(200))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask { _ = try await stub.send(makeRequest("https://e-hentai.org/\(index)")) }
            }
            try await group.waitForAll()
        }

        #expect(stub.requests.count == 100)
    }
}
