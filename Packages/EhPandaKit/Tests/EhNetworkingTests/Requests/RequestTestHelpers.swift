import EhModels
import EhNetworking
import Foundation
import Testing

/// Shared expectations for request-builder tests. Names are prefixed so they cannot clash
/// with helpers other test files in this target define.
enum RequestTesting {
    static let eh = EhRequestBuilder(host: .ehentai)
    static let ex = EhRequestBuilder(host: .exhentai)

    static func builder(_ host: GalleryHost) -> EhRequestBuilder {
        EhRequestBuilder(host: host)
    }

    /// `https://e-hentai.org` or `https://exhentai.org`, without the trailing slash.
    static func origin(_ host: GalleryHost) -> String {
        switch host {
        case .ehentai: "https://e-hentai.org"
        case .exhentai: "https://exhentai.org"
        }
    }

    static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            Issue.record("Invalid test URL \(string)")
            return URL(fileURLWithPath: "/")
        }
        return url
    }

    static func body(_ request: URLRequest) -> String? {
        request.httpBody.map { String(decoding: $0, as: UTF8.self) }
    }

    static func json(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func expectGET(_ request: URLRequest, _ url: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(request.url?.absoluteString == url, sourceLocation: sourceLocation)
        #expect(request.httpMethod == "GET", sourceLocation: sourceLocation)
        #expect(request.httpBody == nil, sourceLocation: sourceLocation)
        #expect(request.allHTTPHeaderFields?.isEmpty ?? true, sourceLocation: sourceLocation)
    }

    static func expectFormPOST(
        _ request: URLRequest, _ url: String, body: String, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(request.url?.absoluteString == url, sourceLocation: sourceLocation)
        #expect(request.httpMethod == "POST", sourceLocation: sourceLocation)
        #expect(
            request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded",
            sourceLocation: sourceLocation
        )
        #expect(Self.body(request) == body, sourceLocation: sourceLocation)
    }

    /// API calls: POST to `api.php` with a JSON body and, as in legacy, no headers.
    static func expectJSONPOST(
        _ request: URLRequest, _ url: String, body: String, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(request.url?.absoluteString == url, sourceLocation: sourceLocation)
        #expect(request.httpMethod == "POST", sourceLocation: sourceLocation)
        #expect(request.allHTTPHeaderFields?.isEmpty ?? true, sourceLocation: sourceLocation)
        #expect(Self.body(request) == body, sourceLocation: sourceLocation)
    }
}
