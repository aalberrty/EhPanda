import EhTestSupport
import Foundation
import Testing
@testable import EhNetworking

/// `DFLoader` against a TLS server on loopback. Unless a test says otherwise the loader trusts
/// the test root, so the server's certificate is good for `e-hentai.org` and nothing else.
@Suite(.timeLimit(.minutes(2)))
struct DFLoaderTests {
    @Test func sendsTheRequestToTheAddressForItsDomain() async throws {
        let server = try await LocalServer { _ in .text("front page") }
        defer { server.stop() }
        let storage = InMemoryCookieStorage()
        storage.setCookie(makeCookie("ipb_member_id", "42"))
        var request = makeLoginRequest(server.url("/bounce_login.php?b=d"))
        request.setValue("Agent", forHTTPHeaderField: "User-Agent")

        let outcome = await DFLoader.local(cookieStorage: storage).outcome(of: request)

        #expect(outcome.error == nil)
        #expect(outcome.didFinish)
        #expect(outcome.response?.statusCode == 200)
        #expect(outcome.response?.url == server.url("/bounce_login.php?b=d"))
        #expect(outcome.response?.expectedContentLength == 10)
        #expect(String(decoding: outcome.body, as: UTF8.self) == "front page")

        let received = try #require(server.record.requests.first)
        #expect(server.record.requests.count == 1)
        #expect(received.method == "POST")
        #expect(received.target == "/bounce_login.php?b=d")
        #expect(received.headers["host"] == "e-hentai.org")
        #expect(received.headers["cookie"] == "ipb_member_id=42")
        #expect(received.headers["user-agent"] == "Agent")
        #expect(received.body == Data("UserName=me&PassWord=SECRET-PASSWORD".utf8))
    }

    @Test func storesResponseCookiesForTheDomain() async throws {
        let server = try await LocalServer { _ in
            .text("ok", headers: [
                ("Set-Cookie", "ipb_member_id=42; Domain=.e-hentai.org; Path=/"),
                ("Set-Cookie", "sk=abc; Path=/")
            ])
        }
        defer { server.stop() }
        let storage = InMemoryCookieStorage()

        let outcome = await DFLoader.local(cookieStorage: storage).outcome(of: URLRequest(url: server.url()))

        #expect(outcome.didFinish)
        let stored = Dictionary(uniqueKeysWithValues: (storage.cookies ?? []).map { ($0.name, $0) })
        #expect(stored["ipb_member_id"]?.value == "42")
        #expect(stored["ipb_member_id"]?.domain == ".e-hentai.org")
        #expect(stored["sk"]?.value == "abc")
        #expect(stored["sk"]?.domain == "e-hentai.org")
        #expect(stored.count == 2)
    }

    @Test func reportsARedirectAgainstTheDomainWithoutFollowingIt() async throws {
        let server = try await LocalServer { _ in
            LocalReply(status: 302, headers: [("Location", "/popular"), ("Set-Cookie", "event=1; Path=/")])
        }
        defer { server.stop() }
        let storage = InMemoryCookieStorage()

        let outcome = await DFLoader.local(cookieStorage: storage).outcome(of: makeLoginRequest(server.url("/login")))

        let redirect = try #require(outcome.redirect)
        #expect(redirect.request.url == server.url("/popular"))
        #expect(redirect.request.httpMethod == "GET")
        #expect(redirect.request.httpBody == nil)
        #expect(redirect.response.statusCode == 302)
        #expect(redirect.response.url == server.url("/login"))
        // Only the redirect is reported, and the target is left to the caller.
        #expect(outcome.events.count == 1)
        #expect(server.record.requests.map(\.target) == ["/login"])
        #expect(storage.cookies?.map(\.name) == ["event"])
    }

    @Test func aRedirectWithoutALocationIsAnOrdinaryResponse() async throws {
        let server = try await LocalServer { _ in LocalReply(status: 302, body: Data("moved".utf8)) }
        defer { server.stop() }

        let outcome = await DFLoader.local().outcome(of: URLRequest(url: server.url()))

        #expect(outcome.redirect == nil)
        #expect(outcome.response?.statusCode == 302)
        #expect(String(decoding: outcome.body, as: UTF8.self) == "moved")
        #expect(outcome.didFinish)
    }

    @Test func passesACompressedBodyOnDecodedWithoutItsCompressedLength() async throws {
        // 8000 bytes of text, 68 bytes compressed.
        let gzip = "H4sIAAAAAAAC/+3HsQkAIAwAsFd8TShKByuI/+MhJltir57Vxtl1s2YLd3d3d3d3d3d3d3d3d3f3D/8AhEmeokAfAAA="
        let compressed = try #require(Data(base64Encoded: gzip))
        let server = try await LocalServer { _ in
            LocalReply(headers: [("Content-Encoding", "gzip"), ("Content-Type", "text/plain")], body: compressed)
        }
        defer { server.stop() }

        let outcome = await DFLoader.local().outcome(of: URLRequest(url: server.url()))

        #expect(outcome.body == Data(String(repeating: "domain fronting ", count: 500).utf8))
        let response = try #require(outcome.response)
        #expect(response.expectedContentLength != 68)
        #expect([-1, 8000].contains(response.expectedContentLength))
    }

    @Test func reusesAConnectionForTheSameDomainOnly() async throws {
        let server = try await LocalServer { _ in .text("ok") }
        defer { server.stop() }
        let storage = InMemoryCookieStorage()
        storage.setCookie(makeCookie("igneous", "SECRET-EX", domain: "exhentai.org"))
        let loader = DFLoader.local(cookieStorage: storage)

        #expect(await loader.outcome(of: URLRequest(url: server.url("/1"))).didFinish)
        #expect(await loader.outcome(of: URLRequest(url: server.url("/2"))).didFinish)
        // Both went over one authenticated connection, which is still open.
        #expect(server.record.handshakes == 1)

        // The same address and port, now for a domain the certificate is not good for. Reusing
        // the open connection would skip the check.
        let other = await loader.outcome(of: makeLoginRequest(server.url("/3", domain: "exhentai.org")))

        #expect(other.error?.code == .serverCertificateUntrusted)
        #expect(server.record.requests.map(\.target) == ["/1", "/2"])
        #expect(!server.receivedText.contains("SECRET"))
    }

    @Test func reportsFailuresForTheDomainsURL() async throws {
        // Nothing listens on the port once the server has stopped.
        let server = try await LocalServer()
        await server.stopListening()

        let outcome = await DFLoader.local().outcome(of: URLRequest(url: server.url("/g/1/")))

        let error = try #require(outcome.error)
        #expect(error.code == .cannotConnectToHost)
        #expect(error.failingURL == server.url("/g/1/"))
        #expect(outcome.events.count == 1)
    }

    @Test func cancellingStopsTheLoad() async throws {
        let server = try await LocalServer { _ in .silence }
        defer { server.stop() }
        let log = EventLog()

        let load = DFLoader.local().load(URLRequest(url: server.url("/hang")), onEvent: log.append)
        #expect(await eventually { server.record.requests.count == 1 })
        load.cancel()

        // The connection goes away with the request, and the cancellation is not reported.
        #expect(await server.connectionsDidEnd())
        #expect(log.all.isEmpty)
    }
}

/// The reason domain fronting exists, and the reason it must authenticate first.
@Suite(.timeLimit(.minutes(2)))
struct DFLoaderHandshakeTests {
    /// What an impostor on one of the fixed addresses can do: present a certificate for the
    /// right name that no trusted authority issued.
    @Test func sendsNothingToAServerTheSystemDoesNotTrust() async throws {
        let server = try await LocalServer()
        defer { server.stop() }
        let storage = InMemoryCookieStorage()
        storage.setCookie(makeCookie("ipb_pass_hash", "SECRET-HASH"))
        // `DFTrust.evaluate`, exactly as the app runs it.
        let loader = DFLoader.local(cookieStorage: storage, evaluateTrust: DFTrust.evaluate)

        let outcome = await loader.outcome(of: makeLoginRequest(server.url("/bounce_login.php")))

        #expect(outcome.error?.code == .serverCertificateUntrusted)
        #expect(outcome.error?.failingURL == server.url("/bounce_login.php"))
        #expect(outcome.events.count == 1)
        // The client did reach the server, and gave up before the handshake completed.
        #expect(await server.connectionsDidEnd())
        #expect(server.record.connections >= 1)
        #expect(server.record.handshakes == 0)
        #expect(server.record.received.isEmpty)
    }

    /// The other thing an impostor can do: present a certificate a trusted authority did issue,
    /// for a name of its own.
    @Test func sendsNothingToAServerWithACertificateForAnotherDomain() async throws {
        let server = try await LocalServer()
        defer { server.stop() }
        let storage = InMemoryCookieStorage()
        storage.setCookie(makeCookie("igneous", "SECRET-EX", domain: "exhentai.org"))

        let request = makeLoginRequest(server.url("/", domain: "exhentai.org"))
        let outcome = await DFLoader.local(cookieStorage: storage).outcome(of: request)

        #expect(outcome.error?.code == .serverCertificateUntrusted)
        #expect(await server.connectionsDidEnd())
        #expect(server.record.connections >= 1)
        #expect(server.record.handshakes == 0)
        #expect(server.record.received.isEmpty)
    }

    /// The same request as the two above, to the same kind of server, with a certificate that is
    /// good: the server does record the secrets, so the tests above would notice them.
    @Test func theSameRequestReachesAServerItCanAuthenticate() async throws {
        let server = try await LocalServer()
        defer { server.stop() }
        let storage = InMemoryCookieStorage()
        storage.setCookie(makeCookie("ipb_pass_hash", "SECRET-HASH"))

        let request = makeLoginRequest(server.url("/bounce_login.php"))
        let outcome = await DFLoader.local(cookieStorage: storage).outcome(of: request)

        #expect(outcome.didFinish)
        #expect(server.record.handshakes == 1)
        #expect(server.receivedText.hasPrefix("POST /bounce_login.php HTTP/1.1\r\n"))
        #expect(server.receivedText.contains("ipb_pass_hash=SECRET-HASH"))
        #expect(server.receivedText.contains("PassWord=SECRET-PASSWORD"))
    }

    /// What a filter on the network sees of a fronted connection.
    @Test func theHandshakeDoesNotNameTheDomain() async throws {
        // No identity: the server records the raw start of the connection instead of answering.
        let server = try await LocalServer(identity: nil)
        defer { server.stop() }

        let load = DFLoader.local().load(URLRequest(url: server.url("/g/1/"))) { _ in }
        defer { load.cancel() }
        #expect(await eventually { ClientHello(record: server.record.received) != nil })

        let hello = try #require(ClientHello(record: server.record.received))
        #expect(hello.serverName == nil)
        #expect(hello.protocols.contains("http/1.1"))
        #expect(!server.receivedText.contains("e-hentai"))
    }
}
