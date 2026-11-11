import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

struct ClientErrorTests {
    @Test(arguments: [
        URLError.Code.timedOut, .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
        .cannotConnectToHost, .badServerResponse, .secureConnectionFailed, .unknown
    ])
    func urlErrorsBecomeNetworkingFailed(code: URLError.Code) async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .error(URLError(code)))

        let error = await thrownError { try await harness.client.ehSetting() }

        #expect(error as? AppError == .networkingFailed)
    }

    @Test func cancelledURLErrorBecomesCancellationError() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .error(URLError(.cancelled)))

        let error = await thrownError { try await harness.client.ehSetting() }

        #expect(error is CancellationError)
    }

    @Test func parserFailurePassesThrough() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html("<p></p>"))

        let error = await thrownError { try await harness.client.ehSetting() }

        #expect(error as? AppError == .parseFailed)
    }

    @Test func decodingErrorBecomesParseFailed() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .handler { _ in
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "test"))
        })

        let error = await thrownError { try await harness.client.greeting() }

        #expect(error as? AppError == .parseFailed)
    }

    @Test func foreignErrorBecomesUnknown() async {
        // No route: the stub throws its own `Unmatched` error.
        let harness = ClientHarness()

        let error = await thrownError { try await harness.client.greeting() }

        #expect(error as? AppError == .unknown)
    }

    @Test func cancellationWhileSuspended() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .suspendUntilCancelled)

        let task = Task { try await harness.client.galleryDetail(gid: "1", galleryURL: clientURL("https://e-hentai.org/g/1/a/")) }
        try await waitUntil { harness.requests.count == 1 }
        task.cancel()
        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
    }

    @Test func cancellationInTheMiddleOfAChain() async throws {
        let harness = ClientHarness()
        harness.transport.on(.path("/g/3103480/0000000000/"), reply: .fixture(ClientFixture.detail))
        harness.transport.on(.path("/archiver.php"), reply: .suspendUntilCancelled)

        let task = Task {
            try await harness.client.archiveFunds(galleryURL: clientURL("https://e-hentai.org/g/3103480/0000000000/"))
        }
        try await waitUntil { harness.requests.count == 2 }
        task.cancel()
        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
    }

    @Test func failureOfACancelledTaskIsReportedAsCancellation() async {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .error(URLError(.timedOut)))

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await harness.client.ehSetting()
        }
        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
    }
}

struct ClientHostTests {
    @Test func eachCallUsesTheHostSelectedAtThatTime() async throws {
        let harness = ClientHarness()
        let client = harness.client
        harness.transport.on(.any, reply: .fixture(ClientFixture.ehSetting))

        _ = try await client.ehSetting()
        harness.host = .exhentai
        _ = try await client.ehSetting()

        #expect(harness.requests.map(line) == [
            "GET https://e-hentai.org/uconfig.php",
            "GET https://exhentai.org/uconfig.php"
        ])
    }

    @Test func aCallKeepsTheHostItStartedWith() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .handler { [harness] request in
            // The user switches sites while the request is in flight.
            harness.host = .exhentai
            let body = Data(#"{"i":"https://h.example/1.jpg","s":"1-1","lf":"fullimg/1/1/a/1.jpg"}"#.utf8)
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return HTTPResponse(data: body, response: response)
        })

        let image = try await harness.client.mpvPageImage(gid: "1", index: 1, mpvKey: "m", imageKey: "i")

        #expect(harness.requests.first?.url?.host() == "e-hentai.org")
        #expect(image.image.originalImageURL?.host() == "e-hentai.org")
    }
}
