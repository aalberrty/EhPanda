import EhModels
import Foundation

/// Reads and writes the site's login and preference cookies in an `HTTPCookieStorage`.
///
/// `HTTPCookieStorage` is thread-safe, so the store can be used from any context.
public struct CookieStore: Sendable {
    private let storage: HTTPCookieStorage

    public init(storage: HTTPCookieStorage = .shared) {
        self.storage = storage
    }

    static let ehentaiURL = GalleryHost.ehentai.url
    static let exhentaiURL = GalleryHost.exhentai.url
    // The image host of ExHentai, which needs the same login cookies as the main site.
    static let sexhentaiURL = URL(string: "https://s.exhentai.org/")!
    static let oneYear: TimeInterval = 60 * 60 * 24 * 365

    // MARK: Primitives

    /// The value of the cookie named `name` for `url`. When several cookies match, the last wins.
    /// Cookies without an expiry date (session cookies) are ignored.
    public func cookie(named name: String, for url: URL) -> CookieValue {
        var value = CookieValue.empty
        for cookie in storage.cookies(for: url) ?? [] {
            guard let expiresDate = cookie.expiresDate, cookie.name == name, !cookie.value.isEmpty
            else { continue }
            if expiresDate <= .now {
                value = CookieValue(rawValue: "", status: .expired)
            } else if cookie.value == CookieValueConstant.mystery {
                value = CookieValue(rawValue: cookie.value, status: .mystery)
            } else {
                value = CookieValue(rawValue: cookie.value, status: .valid)
            }
        }
        return value
    }

    /// Replaces the value of an existing cookie, keeping its other properties, or creates one
    /// on path `/` that expires in a year.
    public func setOrEditCookie(for url: URL, name: String, value: String) {
        if containsCookie(named: name, for: url) {
            editCookie(for: url, name: name, value: value)
        } else {
            setCookie(for: url, name: name, value: value)
        }
    }

    /// Deletes every cookie in the storage.
    public func clearAll() {
        storage.cookies?.forEach(storage.deleteCookie)
    }

    func setCookie(
        for url: URL, name: String, value: String, path: String = "/", expiresIn: TimeInterval = oneYear
    ) {
        let properties: [HTTPCookiePropertyKey: Any] = [
            .path: path, .name: name, .value: value,
            .originURL: url, .expires: Date(timeIntervalSinceNow: expiresIn)
        ]
        if let cookie = HTTPCookie(properties: properties) {
            storage.setCookie(cookie)
        }
    }

    func removeCookie(named name: String, for url: URL) {
        storage.cookies(for: url)?
            .filter { $0.name == name }
            .forEach(storage.deleteCookie)
    }

    private func containsCookie(named name: String, for url: URL) -> Bool {
        storage.cookies(for: url)?.contains { $0.name == name } ?? false
    }

    private func editCookie(for url: URL, name: String, value: String) {
        var replacement: HTTPCookie?
        for cookie in storage.cookies(for: url) ?? [] where cookie.name == name {
            var properties = cookie.properties ?? [:]
            properties[.value] = value
            replacement = HTTPCookie(properties: properties)
        }
        removeCookie(named: name, for: url)
        if let replacement {
            storage.setCookie(replacement)
        }
    }
}

// MARK: Accessors

extension CookieStore {
    /// Whether either host holds a complete, unexpired login. ExHentai also needs a usable `igneous`.
    public var didLogin: Bool {
        hasLogin(for: Self.ehentaiURL, requiresIgneous: false)
            || hasLogin(for: Self.exhentaiURL, requiresIgneous: true)
    }

    /// The member id (the API's `apiuid`) on `host`, or an empty string.
    public func memberID(for host: GalleryHost) -> String {
        cookie(named: CookieName.ipbMemberId, for: host.url).rawValue
    }

    public func passHash(for host: GalleryHost) -> String {
        cookie(named: CookieName.ipbPassHash, for: host.url).rawValue
    }

    public func igneous(for host: GalleryHost) -> String {
        cookie(named: CookieName.igneous, for: host.url).rawValue
    }

    /// Both hosts are logged in with the same member id.
    public var isSameAccount: Bool {
        let ehUID = memberID(for: .ehentai)
        let exUID = memberID(for: .exhentai)
        return !ehUID.isEmpty && !exUID.isEmpty && ehUID == exUID
    }

    /// ExHentai has a login but no `igneous` yet, which a visit to the site would provide.
    public var shouldFetchIgneous: Bool {
        !memberID(for: .exhentai).isEmpty
            && !passHash(for: .exhentai).isEmpty
            && igneous(for: .exhentai).isEmpty
    }

    public func loadCookiesState(host: GalleryHost) -> CookiesState {
        func state(_ name: String) -> CookieState {
            let value = cookie(named: name, for: host.url)
            return CookieState(key: name, value: value, editingText: value.rawValue)
        }
        return CookiesState(
            host: host,
            igneous: state(CookieName.igneous),
            memberID: state(CookieName.ipbMemberId),
            passHash: state(CookieName.ipbPassHash)
        )
    }

    /// The non-empty login cookies of `host` as text for the clipboard, for example
    /// `["igneous": "…", "ipb_member_id": "…"]`. Keys are sorted so the text is stable.
    public func cookiesDescription(host: GalleryHost) -> String {
        let pairs = CookieName.credentials.sorted().compactMap { name -> String? in
            let value = cookie(named: name, for: host.url).rawValue
            return value.isEmpty ? nil : "\"\(name)\": \"\(value)\""
        }
        return pairs.isEmpty ? "[:]" : "[" + pairs.joined(separator: ", ") + "]"
    }

    private func hasLogin(for url: URL, requiresIgneous: Bool) -> Bool {
        var igneous, memberID, passHash: String?
        for cookie in storage.cookies(for: url) ?? [] {
            guard let expiresDate = cookie.expiresDate, expiresDate > .now, !cookie.value.isEmpty
            else { continue }
            switch cookie.name {
            case CookieName.igneous where cookie.value != CookieValueConstant.mystery:
                igneous = cookie.value
            case CookieName.ipbMemberId:
                memberID = cookie.value
            case CookieName.ipbPassHash:
                passHash = cookie.value
            default:
                break
            }
        }
        return (!requiresIgneous || igneous != nil) && memberID != nil && passHash != nil
    }
}

// MARK: Maintenance

extension CookieStore {
    /// Removes the `yay` cookie, which makes ExHentai serve a blank page.
    public func removeYay() {
        removeCookie(named: CookieName.yay, for: Self.exhentaiURL)
        removeCookie(named: CookieName.yay, for: Self.sexhentaiURL)
    }

    /// Copies the ExHentai login cookies to its image host.
    public func syncExCookies() {
        for name in CookieName.credentials {
            setOrEditCookie(
                for: Self.sexhentaiURL, name: name,
                value: cookie(named: name, for: Self.exhentaiURL).rawValue
            )
        }
    }

    /// Skips the offensive-content warning on both hosts.
    public func ignoreOffensive() {
        setOrEditCookie(for: Self.ehentaiURL, name: CookieName.ignoreOffensive, value: "1")
        setOrEditCookie(for: Self.exhentaiURL, name: CookieName.ignoreOffensive, value: "1")
    }

    /// When only one host has a member id and pass hash, copies them to the other.
    public func fulfillAnotherHostField() {
        let ehMemberID = memberID(for: .ehentai)
        let ehPassHash = passHash(for: .ehentai)
        let exMemberID = memberID(for: .exhentai)
        let exPassHash = passHash(for: .exhentai)

        if !ehMemberID.isEmpty && !ehPassHash.isEmpty && (exMemberID.isEmpty || exPassHash.isEmpty) {
            setOrEditCookie(for: Self.exhentaiURL, name: CookieName.ipbMemberId, value: ehMemberID)
            setOrEditCookie(for: Self.exhentaiURL, name: CookieName.ipbPassHash, value: ehPassHash)
        } else if !exMemberID.isEmpty && !exPassHash.isEmpty && (ehMemberID.isEmpty || ehPassHash.isEmpty) {
            setOrEditCookie(for: Self.ehentaiURL, name: CookieName.ipbMemberId, value: exMemberID)
            setOrEditCookie(for: Self.ehentaiURL, name: CookieName.ipbPassHash, value: exPassHash)
        }
    }
}

// MARK: Writing

extension CookieStore {
    /// Writes the edited login cookies to every URL of the state's host.
    public func setCookies(state: CookiesState, trimsSpaces: Bool = true) {
        for cookieState in state.allCases {
            let value = trimsSpaces
                ? cookieState.editingText.trimmingCharacters(in: .whitespaces)
                : cookieState.editingText
            for url in state.host.cookieURLs {
                setOrEditCookie(for: url, name: cookieState.key, value: value)
            }
        }
    }

    /// Stores the login cookies from a login response's `Set-Cookie` header on both hosts.
    /// E-Hentai never receives `igneous`. Needed because responses served through domain
    /// fronting bypass the session's cookie handling.
    public func setCredentials(response: HTTPURLResponse) {
        for field in setCookieFields(of: response) {
            for url in [Self.ehentaiURL, Self.exhentaiURL] {
                for name in CookieName.credentials {
                    guard !(url == Self.ehentaiURL && name == CookieName.igneous),
                          let range = field.range(of: "\(name)=")
                    else { continue }
                    setCookie(for: url, name: name, value: String(field[range.upperBound...]))
                }
            }
        }
    }

    /// Stores the `skipserver` cookie from an image page response, scoped to `/s/` on `host`.
    public func setSkipServer(response: HTTPURLResponse, host: GalleryHost) {
        let name = CookieName.skipServer
        for field in setCookieFields(of: response) {
            if let range = field.range(of: "\(name)=") {
                setCookie(for: host.url, name: name, value: String(field[range.upperBound...]), path: "/s/")
            }
        }
    }

    /// The `Set-Cookie` header split into its `name=value` and attribute fields.
    private func setCookieFields(of response: HTTPURLResponse) -> [String] {
        guard let header = response.value(forHTTPHeaderField: "Set-Cookie") else { return [] }
        return header.components(separatedBy: ", ").flatMap { $0.components(separatedBy: "; ") }
    }
}
