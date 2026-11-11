import EhTestSupport
import Foundation
import Synchronization
import Testing
@testable import EhNetworking

struct RetryingTransportTests {
    let stub = StubTransport()
    let recorder = SleepRecorder()

    func transport(random: Double = 0) -> RetryingTransport {
        RetryingTransport(
            stub,
            policy: RetryPolicy(maxAttempts: 3, baseDelay: .milliseconds(500), jitterFraction: 0.25),
            sleep: recorder.sleep,
            random: { random }
        )
    }

    @Test func succeedsAfterScriptedFailures() async throws {
        stub.on(.any, replies: .error(URLError(.timedOut)), .error(URLError(.networkConnectionLost)), .html("ok"))

        let response = try await transport().send(makeRequest())

        #expect(String(decoding: response.data, as: UTF8.self) == "ok")
        #expect(stub.requests.count == 3)
        #expect(recorder.delays == [.milliseconds(500), .milliseconds(1000)])
    }

    @Test func backoffIncludesJitter() async throws {
        stub.on(.any, replies: .error(URLError(.timedOut)), .error(URLError(.timedOut)), .status(200))

        _ = try await transport(random: 0.5).send(makeRequest())

        #expect(recorder.delays == [.microseconds(562_500), .microseconds(1_125_000)])
    }

    @Test(arguments: ["GET", "HEAD"])
    func idempotentRequestsStopAfterThreeAttempts(method: String) async {
        stub.on(.any, reply: .error(URLError(.timedOut)))

        let error = await #expect(throws: URLError.self) {
            try await transport().send(makeRequest(method: method))
        }

        #expect(error?.code == .timedOut)
        #expect(stub.requests.count == 3)
        #expect(recorder.delays.count == 2)
    }

    @Test(arguments: [URLError.Code.timedOut, .networkConnectionLost, .badServerResponse, .unknown])
    func postIsNotReplayedWhenItMayHaveBeenDelivered(code: URLError.Code) async {
        stub.on(.any, replies: .error(URLError(code)), .status(200))

        await #expect(throws: URLError(code)) {
            try await transport().send(makeRequest(method: "POST"))
        }
        #expect(stub.requests.count == 1)
        #expect(recorder.delays.isEmpty)
    }

    @Test(arguments: [URLError.Code.cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .notConnectedToInternet])
    func postIsRetriedWhenItNeverLeft(code: URLError.Code) async throws {
        stub.on(.any, replies: .error(URLError(code)), .status(200))

        let response = try await transport().send(makeRequest(method: "POST"))

        #expect(response.statusCode == 200)
        #expect(stub.requests.count == 2)
    }

    @Test func cancelledErrorIsNotRetried() async {
        stub.on(.any, replies: .error(URLError(.cancelled)), .status(200))

        await #expect(throws: URLError(.cancelled)) {
            try await transport().send(makeRequest())
        }
        #expect(stub.requests.count == 1)
    }

    @Test func nonRetryableErrorIsThrownImmediately() async {
        stub.on(.any, replies: .error(URLError(.badURL)), .status(200))

        await #expect(throws: URLError(.badURL)) {
            try await transport().send(makeRequest())
        }
        #expect(stub.requests.count == 1)
    }

    @Test func otherErrorsBecomeUnknownURLErrors() async {
        struct Boom: Error {}
        stub.on(.any, reply: .error(Boom()))

        let error = await #expect(throws: URLError.self) {
            try await transport().send(makeRequest())
        }
        #expect(error?.code == .unknown)
        #expect(error?.userInfo[NSUnderlyingErrorKey] is Boom)
        #expect(stub.requests.count == 3)
    }

    @Test func errorStatusesAreReturnedNotRetried() async throws {
        stub.on(.any, reply: .status(503))

        let response = try await transport().send(makeRequest())

        #expect(response.statusCode == 503)
        #expect(stub.requests.count == 1)
    }

    @Test func cancellingWhileTheRequestIsSuspendedThrowsPromptly() async throws {
        stub.on(.any, reply: .suspendUntilCancelled)
        let transport = transport()
        let task = Task { try await transport.send(makeRequest()) }
        try await waitUntil { stub.requests.count == 1 }

        let start = ContinuousClock.now
        task.cancel()
        let result = await task.result

        #expect(ContinuousClock.now - start < .seconds(1))
        #expect(throws: URLError(.cancelled)) { try result.get() }
        #expect(stub.requests.count == 1)
        #expect(recorder.delays.isEmpty)
    }

    @Test func cancellingDuringBackoffStopsRetrying() async throws {
        stub.on(.any, reply: .error(URLError(.timedOut)))
        let sleeping = Mutex(false)
        let transport = RetryingTransport(stub, sleep: { duration in
            sleeping.withLock { $0 = true }
            try await Task.sleep(for: .seconds(3600))
        })
        let task = Task { try await transport.send(makeRequest()) }
        try await waitUntil { sleeping.withLock { $0 } }

        task.cancel()
        let result = await task.result

        #expect(throws: URLError(.cancelled)) { try result.get() }
        #expect(stub.requests.count == 1)
    }
}
