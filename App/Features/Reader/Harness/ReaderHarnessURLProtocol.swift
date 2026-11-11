#if DEBUG
import Foundation
import os

/// Stands in for the image servers in the reader harness.
///
/// Harness page URLs point at a host that does not exist; this protocol answers them with a
/// generated image, delivered in pieces over the requested latency. That way the harness goes
/// through the real download path of `ImagePipeline` (progress, cancellation, disk cache), and
/// a URL can be made to fail.
///
/// `@unchecked Sendable`: URL loading hands a protocol instance between its own threads, and
/// the only state added here is the stop flag, which is behind a lock.
nonisolated final class ReaderHarnessURLProtocol: URLProtocol, @unchecked Sendable {
    static let host = "reader-harness.invalid"

    private static let queue = DispatchQueue(label: "app.ehpanda.reader-harness", qos: .utility, attributes: .concurrent)
    private static let chunkCount = 10

    private let isStopped = OSAllocatedUnfairLock(initialState: false)

    /// The URL of a page's image. A new `attempt` is a new URL; `latency` is how long the
    /// download takes; `fails` makes the server answer with an error.
    static func url(forPage page: Int, session: String, attempt: Int, latency: Double, fails: Bool) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        let spec = ReaderHarnessImages.spec(forPage: page)
        components.path = "/\(session)/\(page)-\(attempt).\(spec.fileExtension)"
        components.queryItems = [
            URLQueryItem(name: "latency", value: String(format: "%.2f", latency)),
            URLQueryItem(name: "fails", value: fails ? "1" : "0")
        ]
        return components.url
    }

    /// Makes the reader's downloader answer harness URLs. Safe to call more than once.
    static func install() {
        let configuration = ImagePipeline.downloader.sessionConfiguration
        let installed = configuration.protocolClasses ?? []
        guard !installed.contains(where: { $0 == ReaderHarnessURLProtocol.self }) else { return }
        configuration.protocolClasses = [ReaderHarnessURLProtocol.self] + installed
        ImagePipeline.downloader.sessionConfiguration = configuration
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let page = Int(url.deletingPathExtension().lastPathComponent.split(separator: "-").first ?? "")
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let query = Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first }
        )
        let latency = Double(query["latency"] ?? "") ?? 0
        let fails = query["fails"] == "1"

        Self.queue.async {
            if fails {
                self.respond(to: url, status: 503, body: Data(), latency: latency)
            } else if let data = ReaderHarnessImages.data(forPage: page) {
                self.respond(to: url, status: 200, body: data, latency: latency)
            } else {
                self.finish { $0.urlProtocol(self, didFailWithError: URLError(.cannotDecodeContentData)) }
            }
        }
    }

    override func stopLoading() {
        isStopped.withLock { $0 = true }
    }

    private func respond(to url: URL, status: Int, body: Data, latency: Double) {
        let headers = ["Content-Length": String(body.count)]
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
            finish { $0.urlProtocol(self, didFailWithError: URLError(.badServerResponse)) }
            return
        }
        let chunkSize = max(body.count / Self.chunkCount, 1)
        let interval = latency / Double(Self.chunkCount)
        deliver(body, from: 0, chunkSize: chunkSize, interval: interval, response: response)
    }

    /// Sends the response, then one chunk per interval, then the end of the load.
    private func deliver(_ body: Data, from offset: Int, chunkSize: Int, interval: Double, response: HTTPURLResponse) {
        guard !isStopped.withLock({ $0 }) else { return }
        if offset == 0 {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        guard offset < body.count else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let end = min(offset + chunkSize, body.count)
        client?.urlProtocol(self, didLoad: body.subdata(in: offset..<end))
        Self.queue.asyncAfter(deadline: .now() + interval) {
            self.deliver(body, from: end, chunkSize: chunkSize, interval: interval, response: response)
        }
    }

    private func finish(_ body: (any URLProtocolClient) -> Void) {
        guard !isStopped.withLock({ $0 }), let client else { return }
        body(client)
    }
}
#endif
