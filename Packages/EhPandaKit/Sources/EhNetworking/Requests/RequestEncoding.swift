import Foundation

/// The query vocabulary the site understands (legacy `Defaults.URL.Component.Key`).
enum RequestQueryKey: String {
    case token = "t"
    case gid
    case letterP = "p"
    case next
    case favcat
    case topcat = "tl"
    case showUser = "showuser"
    case fSearch = "f_search"
    case code = "CODE"
    case act
    case showComments = "hc"
    case inlineSet = "inline_set"
    case skipServerIdentifier = "nl"

    // Searching favorites
    case sn, st, sf

    // Filter
    case fCats = "f_cats"
    case advSearch = "advsearch"
    case fSname = "f_sname"
    case fStags = "f_stags"
    case fSdesc = "f_sdesc"
    case fStorr = "f_storr"
    case fSto = "f_sto"
    case fSdt1 = "f_sdt1"
    case fSdt2 = "f_sdt2"
    case fSh = "f_sh"
    case fSr = "f_sr"
    case fSrdd = "f_srdd"
    case fSp = "f_sp"
    case fSpf = "f_spf"
    case fSpt = "f_spt"
    case fSfl = "f_sfl"
    case fSfu = "f_sfu"
    case fSft = "f_sft"

    // App-private keys carried on preview URLs, never sent to the site.
    case ehpandaWidth, ehpandaHeight, ehpandaOffset
}

/// Fixed query values (legacy `Defaults.URL.Component.Value`).
enum RequestQueryValue {
    static let one = "1"
    static let all = "all"
    static let zeroOne = "01"
    static let filterOn = "on"
    static let loginAct = "Login"
    static let addFavAct = "addfav"
    static let sortOrderByUpdateTime = "fs_p"
    static let sortOrderByFavoritedTime = "fs_f"
}

enum RequestEncoding {
    static func item(_ key: RequestQueryKey, _ value: String) -> URLQueryItem {
        URLQueryItem(name: key.rawValue, value: value)
    }

    /// Appends query items the way the legacy `URL.appending(queryItems:)` did: through
    /// `URLComponents.queryItems`, which escapes `&`, `=` and `#` in values but leaves `+`
    /// as is. An empty list leaves the URL untouched (no trailing `?`).
    static func appending(_ items: [URLQueryItem], to url: URL) -> URL {
        guard !items.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        components.queryItems = (components.queryItems ?? []) + items
        return components.url ?? url
    }

    /// Encodes a form body the way the legacy app did: `key=value` pairs joined with `&`,
    /// then the whole string percent-escaped with `.urlQueryAllowed`.
    ///
    /// The site has always received exactly this, so it is kept byte for byte, including
    /// its quirks: `&`, `=` and `+` inside values are not escaped, and an already escaped
    /// sequence such as `%0A` is escaped again to `%250A`. Pairs keep the given order;
    /// legacy used a dictionary, so its order was unspecified and the site ignores it.
    static func formBody(_ fields: [(String, String)]) -> Data? {
        let joined = fields.map { $0 + "=" + $1 }.joined(separator: "&")
        return (joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            .data(using: .utf8)
    }

    static func jsonBody(_ value: some Encodable) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(value)
    }
}

// Request factories live in this namespace, not in a `URLRequest` extension, so they cannot
// collide with helpers the transport layer defines in the same module.
extension RequestEncoding {
    static func get(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return request
    }

    static func postForm(_ url: URL, fields: [(String, String)]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = formBody(fields)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// Legacy sent `api.php` calls without a `Content-Type` header; the site accepts that.
    static func postJSON(_ url: URL, body: some Encodable) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonBody(body)
        return request
    }
}
