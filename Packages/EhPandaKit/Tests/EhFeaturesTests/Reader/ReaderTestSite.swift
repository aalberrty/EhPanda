import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Synchronization
import Testing

/// A made-up gallery served through a `StubTransport`: preview pages, viewer pages, the
/// multi-page viewer and its `imagedispatch` API.
///
/// Every request is recorded under a short key in the order it arrived:
/// `links:<preview page>`, `page:<n>`, `reload:<n>` (a viewer page with `nl`), `mpv`,
/// `dispatch:<n>` and `dispatch:<n>:nl=<id>`. A key can be held (the request waits until it
/// is released or cancelled) and made to fail, which is how the tests see ordering, bounds and
/// cancellation.
nonisolated final class ReaderTestSite: Sendable {
    private struct State {
        var started: [String] = []
        var cancelled: [String] = []
        var inFlight: Set<String> = []
        var maximumInFlight = 0
        var holdsEverything = false
        var held: Set<String> = []
        var released: Set<String> = []
        var failures: [String: Int] = [:]
    }

    let transport = StubTransport()
    let cookies = CookieStore(storage: InMemoryCookieStorage())
    let gid = "1234"
    let token = "abcdef0123"
    let pageCount: Int
    /// Pages per preview page, as the site serves them.
    let batchSize: Int
    let usesMPV: Bool
    /// Keys the multi-page viewer page lists; differs from `pageCount` to provoke "not found".
    let mpvKeyCount: Int

    private let state = Mutex(State())

    init(pageCount: Int = 100, batchSize: Int = 40, usesMPV: Bool = false, mpvKeyCount: Int? = nil) {
        self.pageCount = pageCount
        self.batchSize = batchSize
        self.usesMPV = usesMPV
        self.mpvKeyCount = mpvKeyCount ?? pageCount
        transport.on(.any, reply: .handler { [self] request in try await respond(to: request) })
    }

    var client: EhClient {
        EhClient(transport: transport, cookies: cookies, host: { .ehentai })
    }

    var galleryURL: URL { URL(string: "https://e-hentai.org/g/\(gid)/\(token)/")! }

    var gallery: Gallery {
        Gallery(
            gid: gid, token: token, title: "Title", rating: 4, tags: [], category: .doujinshi,
            pageCount: pageCount, postedDate: Date(timeIntervalSince1970: 0), coverURL: nil,
            galleryURL: galleryURL
        )
    }

    // MARK: What the site serves

    func link(_ page: Int) -> URL { URL(string: "https://e-hentai.org/s/key\(page)/\(gid)-\(page)")! }
    func image(_ page: Int) -> URL { URL(string: "https://img.example/\(gid)/\(page).jpg")! }
    func reloadedImage(_ page: Int) -> URL { URL(string: "https://img.example/\(gid)/\(page)-reloaded.jpg")! }
    func original(_ page: Int) -> URL { URL(string: "https://e-hentai.org/fullimg.php?gid=\(gid)&page=\(page)&key=o")! }
    func mpvImage(_ page: Int) -> URL { URL(string: "https://img.example/\(gid)/\(page)-mpv.jpg")! }
    func reloadedMPVImage(_ page: Int) -> URL { URL(string: "https://img.example/\(gid)/\(page)-mpv-reloaded.jpg")! }
    func mpvOriginal(_ page: Int) -> URL { URL(string: "https://e-hentai.org/fullimg/\(gid)/\(page)")! }

    func pageImage(_ page: Int) -> PageImage {
        PageImage(index: page, imageURL: image(page), originalImageURL: original(page))
    }

    func links(_ pages: ClosedRange<Int>) -> [Int: URL] {
        Dictionary(uniqueKeysWithValues: pages.map { ($0, link($0)) })
    }

    // MARK: Control

    /// Requests in arrival order.
    var started: [String] { state.withLock { $0.started } }
    var cancelled: [String] { state.withLock { $0.cancelled } }
    var inFlight: Set<String> { state.withLock { $0.inFlight } }
    var maximumInFlight: Int { state.withLock { $0.maximumInFlight } }

    func count(of key: String) -> Int { started.count { $0 == key } }

    /// Every request waits until its key is released.
    func holdEverything() { state.withLock { $0.holdsEverything = true } }

    func hold(_ keys: String...) { state.withLock { $0.held.formUnion(keys) } }

    func release(_ keys: String...) {
        state.withLock { state in
            state.held.subtract(keys)
            state.released.formUnion(keys)
        }
    }

    func releaseEverything() {
        state.withLock { state in
            state.holdsEverything = false
            state.held = []
        }
    }

    /// The next `times` requests for `key` fail with a network error.
    func fail(_ key: String, times: Int = 1) { state.withLock { $0.failures[key] = times } }

    // MARK: Responses

    private func respond(to request: URLRequest) async throws -> HTTPResponse {
        guard let url = request.url, let key = key(for: request) else { throw URLError(.badURL) }
        let shouldFail = state.withLock { state -> Bool in
            state.started.append(key)
            state.inFlight.insert(key)
            state.maximumInFlight = max(state.maximumInFlight, state.inFlight.count)
            guard let remaining = state.failures[key], remaining > 0 else { return false }
            state.failures[key] = remaining - 1
            return true
        }
        defer { state.withLock { _ = $0.inFlight.remove(key) } }
        while isHeld(key) {
            // The sleep only ends early when the request's task is cancelled.
            try? await Task.sleep(for: .milliseconds(2))
            if Task.isCancelled { break }
        }
        // Also for a request that was cancelled and released before it got to wait.
        if Task.isCancelled {
            state.withLock { $0.cancelled.append(key) }
            throw URLError(.cancelled)
        }
        if shouldFail { throw URLError(.timedOut) }
        guard let body = body(for: key),
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
        else { throw URLError(.badServerResponse) }
        return HTTPResponse(data: Data(body.utf8), response: response)
    }

    private func isHeld(_ key: String) -> Bool {
        state.withLock { state in
            if state.held.contains(key) { return true }
            return state.holdsEverything && !state.released.contains(key)
        }
    }

    private func key(for request: URLRequest) -> String? {
        guard let url = request.url else { return nil }
        let components = url.pathComponents
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if components.count >= 2, components[1] == "g" {
            return "links:\(query.first { $0.name == "p" }?.value ?? "0")"
        }
        if components.count >= 4, components[1] == "s" {
            let page = components[3].split(separator: "-").last.map(String.init) ?? "?"
            return query.contains { $0.name == "nl" } ? "reload:\(page)" : "page:\(page)"
        }
        if components.count >= 2, components[1] == "mpv" {
            return "mpv"
        }
        if url.lastPathComponent == "api.php", let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let page = json["page"] as? Int
        {
            return (json["nl"] as? String).map { "dispatch:\(page):nl=\($0)" } ?? "dispatch:\(page)"
        }
        return nil
    }

    private func body(for key: String) -> String? {
        let parts = key.split(separator: ":").map(String.init)
        let number = parts.count > 1 ? Int(parts[1]) : nil
        switch parts[0] {
        case "links":
            return number.map(previewPageHTML)
        case "page":
            return number.map { viewerPageHTML($0, image: image($0)) }
        case "reload":
            return number.map { viewerPageHTML($0, image: reloadedImage($0)) }
        case "mpv":
            return mpvHTML
        case "dispatch":
            guard let page = number else { return nil }
            let image = parts.count > 2 ? reloadedMPVImage(page) : mpvImage(page)
            return #"{"i":"\#(image.absoluteString)","s":"skip\#(page)","lf":"fullimg/\#(gid)/\#(page)"}"#
        default:
            return nil
        }
    }

    private func previewPageHTML(_ number: Int) -> String {
        let first = number * batchSize + 1
        let last = min(first + batchSize - 1, pageCount)
        guard first <= last else { return #"<html><body><div id="gdt" class="gt100"></div></body></html>"# }
        let entries = (first...last).map { page -> String in
            let href = usesMPV
                ? "https://e-hentai.org/mpv/\(gid)/\(token)/#page\(page)"
                : link(page).absoluteString
            let offset = (page - first) * 100
            let style = "width:100px;height:145px;background:transparent "
                + "url(https://ehgt.example/\(gid)-\(number).jpg) -\(offset)px 0 no-repeat"
            return #"<a href="\#(href)"><div title="Page \#(page): \#(page).jpg" style="\#(style)"></div></a>"#
        }
        return #"<html><body><div id="gdt" class="gt100">\#(entries.joined())</div></body></html>"#
    }

    /// The preview thumbnail the site lists for a page, as the parser stores it.
    func preview(_ page: Int) -> URL {
        let number = (page - 1) / batchSize
        let offset = (page - 1 - number * batchSize) * 100
        return CombinedPreviewURL.url(
            plainURL: URL(string: "https://ehgt.example/\(gid)-\(number).jpg")!,
            width: "100", height: "145", offset: String(offset)
        )
    }

    private func viewerPageHTML(_ page: Int, image: URL) -> String {
        // The parser takes the first link of the document as the original, so it comes first.
        let original = original(page).absoluteString.replacingOccurrences(of: "&", with: "&amp;")
        return """
        <html><body>
        <div id="i7"><a href="\(original)">Download original</a></div>
        <div id="i3"><img id="img" src="\(image.absoluteString)"></div>
        <div id="i6"><a id="loadfail" onclick="return nl('nl\(page)')">Reload</a></div>
        </body></html>
        """
    }

    private var mpvHTML: String {
        let keys = (1...max(mpvKeyCount, 1)).map { #"{"n":"\#($0).jpg","k":"imgkey\#($0)","t":"t"}"# }
        return """
        <html><body><script type="text/javascript">var gid=\(gid);
        var mpvkey = "mpvkey0";
        var imagelist = [\(keys.joined(separator: ","))];
        var pagecount = \(mpvKeyCount);</script></body></html>
        """
    }
}

/// Polls `condition` on the main actor until it holds, failing the test after `seconds`.
func readerEventually(
    _ seconds: Double = 30,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    let deadline = ContinuousClock.now + .seconds(seconds)
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Condition not met within \(seconds) s", sourceLocation: sourceLocation)
            return
        }
        try? await Task.sleep(for: .milliseconds(2))
    }
}

/// Gives requests that should not start the chance to start, so a test can assert they did not.
func readerSettle() async {
    for _ in 0..<5 {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(10))
    }
}
