import Foundation

// Pure helpers that turn a `URLRequest` into the request domain fronting actually sends.

extension URL {
    func replacingHost(with newHost: String?) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        components.host = newHost
        return components.url
    }
}

extension URLRequest {
    /// Image requests are frequent, so errors for them are not logged.
    var urlContainsImageURL: Bool {
        guard let string = url?.absoluteString else { return false }
        return ["jpg", "jpeg", "png", "gif", "bmp"].contains { string.contains($0) }
    }

    var isHTTPS: Bool { url?.scheme == "https" }

    var hasHostField: Bool { hostKey?.isEmpty == false }

    /// The spelling of the `Host` header key in this request, if it has one.
    var hostKey: String? {
        allHTTPHeaderFields?.keys.first { $0.lowercased() == "host" }
    }

    /// The domain the request is for: its `Host` header when present, otherwise the URL's host.
    var domain: String? {
        if let fields = allHTTPHeaderFields, let hostKey {
            return fields[hostKey]
        }
        return url?.host
    }

    /// `scheme://domain`, used to resolve relative redirects.
    var domainWithScheme: String? {
        guard let scheme = url?.scheme, let domain else { return nil }
        return scheme + "://" + domain
    }

    /// A copy whose URL points at a fixed IP for the domain, with the domain kept in the
    /// `Host` header. Unknown domains are returned unchanged.
    func domainIPReplaced(
        resolve: (String) -> String? = DomainResolver.resolve(domain:)
    ) -> URLRequest {
        guard let domain, let ip = resolve(domain), let newURL = url?.replacingHost(with: ip) else { return self }
        var request = self
        request.url = newURL
        if !hasHostField {
            request.addValue(domain, forHTTPHeaderField: "Host")
        }
        return request
    }

    /// The body of a `POST`. URL loading hands bodies to protocols as a stream, so it is drained here.
    func bodyData() -> Data? {
        if httpMethod != "POST" || httpBody != nil { return httpBody }
        guard let stream = httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var body = Data()
        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: bufferSize)
            if readCount > 0 {
                body.append(buffer, count: readCount)
            } else {
                if readCount < 0, let error = stream.streamError {
                    NetworkLog.logger.error("Domain fronting: reading the request body failed: \(error)")
                }
                break
            }
        }
        return body
    }
}

/// Where a redirect response sends domain fronting next.
/// A relative `Location` is resolved against the original domain (not the IP it connected to).
func dfRedirectURL(location: String, domainWithScheme: String?) -> URL? {
    if let domainWithScheme, let base = URL(string: domainWithScheme) {
        return URL(string: location, relativeTo: base)?.absoluteURL
    }
    return URL(string: location)
}
