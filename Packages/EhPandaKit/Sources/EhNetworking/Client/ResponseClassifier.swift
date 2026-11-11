import EhModels
import EhParser
import Foundation

/// Where a request went, without anything that identifies the user: no cookies, no headers,
/// only the names of its query items.
struct RequestSummary: Sendable, Equatable {
    var method: String
    var host: String
    var path: String
    var queryNames: [String]

    init(_ request: URLRequest) {
        method = request.httpMethod ?? "GET"
        host = request.url?.host() ?? ""
        path = request.url?.path(percentEncoded: true) ?? ""
        queryNames = request.url
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }?
            .map(\.name) ?? []
    }

    /// `GET e-hentai.org/favorites.php?favcat`.
    var logDescription: String {
        let query = queryNames.isEmpty ? "" : "?" + queryNames.joined(separator: "&")
        return "\(method) \(host)\(path)\(query)"
    }
}

/// What the server answered for one request, reduced to what explains a failure.
struct ResponseSnapshot: Sendable, Equatable {
    var request: RequestSummary
    /// Host and path of the response, which differ from the request's after a redirect.
    var host: String
    var path: String
    var status: Int
    /// The MIME type, lowercased, without parameters.
    var contentType: String?
    var byteCount: Int
    /// The start of the body as text, at most `ResponseClassifier.prefixLength` bytes.
    var prefix: String

    init(request: URLRequest, response: HTTPResponse) {
        self.request = RequestSummary(request)
        let url = response.response.url ?? request.url
        host = url?.host() ?? ""
        path = url?.path(percentEncoded: true) ?? ""
        status = response.statusCode
        contentType = response.response.mimeType?.lowercased()
        byteCount = response.data.count
        prefix = String(decoding: response.data.prefix(ResponseClassifier.prefixLength), as: UTF8.self)
    }

    /// `GET e-hentai.org/favorites.php?favcat → e-hentai.org/bounce_login.php, status 200,
    /// text/html, 1307 bytes`.
    var logDescription: String {
        var text = request.logDescription
        if host != request.host || path != request.path {
            text += " → \(host)\(path)"
        }
        return text + ", status \(status), \(contentType ?? "no content type"), \(byteCount) bytes"
    }
}

/// Recognises answers that are not the content an operation asked for (a refused ExHentai
/// session, a login prompt, an IP ban, a server failure) so they can be reported as what
/// they are instead of as a parse error.
///
/// Evidence for each rule (checked against the live site without an account, and against
/// the legacy parser):
/// - exhentai.org answers every page with `200`, `text/html` and an empty body when the
///   login cookies are stale, rejected (`igneous=mystery`) or not entitled. Older versions
///   sent the "sad panda" image instead. Without any cookies it first redirects through
///   forums.e-hentai.org; a cookie-storing `URLSession` ends at the same empty `200`, while a
///   client that drops those cookies loops until `URLError.httpTooManyRedirects`, which
///   `EhClientError.resolve` also reports as a refusal.
/// - e-hentai.org answers pages that need a login (`favorites.php`, `uconfig.php`,
///   `home.php`, `gallerypopups.php`) with a `302` to `bounce_login.php`, a small page that
///   says "This page requires you to log on.".
/// - The IP ban page is plain text ending "The ban expires in …" (legacy `parseBanInterval`).
enum ResponseClassifier {
    static let prefixLength = 4096

    static let exhentaiHost = "exhentai.org"
    static let loginBouncePath = "/bounce_login.php"
    static let loginPromptText = "This page requires you to log on."
    /// The login prompt is about 1.3 KB; a page that merely mentions the phrase is far larger.
    static let loginPromptMaxSize = 8 * 1024

    /// Answers that can never be the page an operation asked for, checked before parsing so
    /// that a parser which tolerates them (a gallery list reads a login prompt as an empty
    /// list) does not report success.
    static func classifyBeforeParsing(_ response: ResponseSnapshot) -> AppError? {
        if isExhentaiRefusal(response) {
            return .exhentaiAccessDenied
        }
        if isLoginPrompt(response) {
            return .loginRequired
        }
        return nil
    }

    /// The reason a response that failed to parse was not a page, or `nil` when it is not
    /// recognised and the failure stays `parseFailed`.
    static func classifyParseFailure(_ response: ResponseSnapshot) -> AppError? {
        if let error = classifyBeforeParsing(response) {
            return error
        }
        if let interval = banInterval(response) {
            return .ipBanned(interval)
        }
        // A 404 the app understands (a removed gallery) parses, so it never gets here.
        return (400..<600).contains(response.status) ? .serverError(response.status) : nil
    }

    private static func isExhentaiRefusal(_ response: ResponseSnapshot) -> Bool {
        guard response.host == exhentaiHost, (200..<300).contains(response.status) else { return false }
        return response.byteCount == 0 || response.contentType?.hasPrefix("image/") == true
    }

    private static func isLoginPrompt(_ response: ResponseSnapshot) -> Bool {
        if response.path == loginBouncePath, response.host.hasSuffix("e-hentai.org") {
            return true
        }
        return response.byteCount <= loginPromptMaxSize && response.prefix.contains(loginPromptText)
    }

    /// The ban page is a single line of plain text, so it fits in the prefix. Should it ever
    /// come wrapped in markup, the sentence ends at the next tag.
    private static func banInterval(_ response: ResponseSnapshot) -> BanInterval? {
        guard let start = response.prefix.range(of: "The ban expires in ")?.lowerBound else { return nil }
        let sentence = response.prefix[start...].prefix { $0 != "<" }
        return Parser.parseBanInterval(text: sentence.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
