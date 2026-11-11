import EhModels
import Foundation

/// A cookie value found in a `Set-Cookie` header, for the host it should be stored on.
public struct ResponseCookie: Sendable, Hashable {
    public let host: GalleryHost
    public let name: String
    public let value: String

    public init(host: GalleryHost, name: String, value: String) {
        self.host = host
        self.name = name
        self.value = value
    }
}

/// Cookie names the parser reads (legacy `Defaults.Cookie`).
public enum CookieName {
    public static let igneous = "igneous"
    public static let ipbMemberId = "ipb_member_id"
    public static let ipbPassHash = "ipb_pass_hash"
    public static let skipServer = "skipserver"
}

extension Parser {
    /// The credentials a login or igneous response sets, in the order legacy
    /// `CookieClient.setCredentials(response:)` stored them (later entries win).
    ///
    /// `ipb_member_id` and `ipb_pass_hash` are returned for both hosts; `igneous` only for
    /// ExHentai.
    ///
    /// - Parameter setCookieHeader: the response's combined `Set-Cookie` header, as
    ///   `HTTPURLResponse.allHeaderFields["Set-Cookie"]` returns it.
    public static func parseCredentialCookies(setCookieHeader: String) -> [ResponseCookie] {
        var cookies = [ResponseCookie]()
        for value in cookieComponents(setCookieHeader) {
            for host in [GalleryHost.ehentai, .exhentai] {
                for name in [CookieName.ipbMemberId, CookieName.ipbPassHash, CookieName.igneous] {
                    guard !(host == .ehentai && name == CookieName.igneous),
                          let range = value.range(of: "\(name)=") else { continue }
                    cookies.append(ResponseCookie(host: host, name: name, value: String(value[range.upperBound...])))
                }
            }
        }
        return cookies
    }

    /// The `skipserver` value an image page response sets, if any (legacy
    /// `CookieClient.setSkipServer(response:)`, which stored it for the current host under
    /// path `/s/`). When the header sets it more than once, the last value wins, as there.
    public static func parseSkipServerCookie(setCookieHeader: String) -> String? {
        var skipServer: String?
        for value in cookieComponents(setCookieHeader) {
            if let range = value.range(of: "\(CookieName.skipServer)=") {
                skipServer = String(value[range.upperBound...])
            }
        }
        return skipServer
    }

    private static func cookieComponents(_ header: String) -> [String] {
        header.components(separatedBy: ", ").flatMap { $0.components(separatedBy: "; ") }
    }
}
