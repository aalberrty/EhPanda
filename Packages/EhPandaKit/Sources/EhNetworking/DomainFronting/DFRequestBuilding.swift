import Foundation

// Pure helpers that turn a `URLRequest` into the request domain fronting sends, and what comes
// back into what the app should see.

extension URL {
    func replacingHost(with newHost: String?) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        components.host = newHost
        return components.url
    }
}

extension URLRequest {
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

    /// The URL the request is for: its own, with `domain` as the host.
    var domainURL: URL? {
        url?.replacingHost(with: domain)
    }

    /// The request that goes on the wire in place of this one, or `nil` when its domain is not fronted.
    ///
    /// - The URL points at a fixed address for the domain. An address is not a name, so the TLS
    ///   handshake carries no server name.
    /// - The domain goes in the `Host` header.
    /// - The cookies stored for the domain are attached here, because the session that sends
    ///   the request sees the address as its host and handles no cookies.
    /// - The body is read into memory.
    func fronted(resolve: (String) -> String?, cookieStorage: HTTPCookieStorage) -> URLRequest? {
        guard let domain, let address = resolve(domain), let addressURL = url?.replacingHost(with: address)
        else { return nil }

        var request = self
        request.url = addressURL
        if !hasHostField {
            request.setValue(domain, forHTTPHeaderField: "Host")
        }
        if let domainURL, let cookies = cookieStorage.cookies(for: domainURL), !cookies.isEmpty {
            for (field, value) in HTTPCookie.requestHeaderFields(with: cookies) {
                request.setValue(value, forHTTPHeaderField: field)
            }
        }
        request.httpShouldHandleCookies = false
        if let body = bodyData() {
            request.httpBody = body
        }
        return request
    }

    /// The request's body. URL loading hands bodies to protocols as a stream, so it is drained here.
    func bodyData() -> Data? {
        if let httpBody { return httpBody }
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

/// Where a redirect response sends domain fronting next: `location` resolved against the URL
/// the app asked for, not against the address the request went to.
func dfRedirectURL(location: String, relativeTo url: URL) -> URL? {
    URL(string: location, relativeTo: url)?.absoluteURL
}

extension HTTPURLResponse {
    /// This response as the app should see it: answering `url`, the URL it asked for, rather
    /// than the address the request went to.
    func readdressed(to url: URL) -> HTTPURLResponse {
        var fields: [String: String] = [:]
        for (name, value) in allHeaderFields {
            if let name = name as? String, let value = value as? String {
                fields[name] = value
            }
        }
        let version = "HTTP/1.1"
        guard let copy = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: version, headerFields: fields)
        else { return self }

        // A copy derives its expected length from `Content-Length`, which for a compressed body
        // is the compressed size, while the body is passed on decoded. Keep the session's own
        // figure so that progress stays right.
        guard copy.expectedContentLength != expectedContentLength else { return copy }
        fields = fields.filter { $0.key.caseInsensitiveCompare("Content-Length") != .orderedSame }
        if expectedContentLength >= 0 {
            fields["Content-Length"] = String(expectedContentLength)
        }
        return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: version, headerFields: fields) ?? copy
    }
}
