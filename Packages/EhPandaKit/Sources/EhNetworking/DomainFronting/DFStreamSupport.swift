import CFNetwork
import Foundation
import Security

// CFNetwork plumbing for domain fronting. `CFReadStreamCreateForHTTPRequest` is deprecated but
// is the only API that lets the app connect to an IP while presenting another `Host`, with
// certificate validation under its own control.

enum DFStreamError: Error {
    case methodNotFound
    case urlNotFound
}

extension CFHTTPMessage {
    var isHeaderComplete: Bool { CFHTTPMessageIsHeaderComplete(self) }

    var url: URL? {
        CFHTTPMessageCopyRequestURL(self)?.takeRetainedValue() as URL?
    }

    var allHeaderFields: [String: String] {
        CFHTTPMessageCopyAllHeaderFields(self)?.takeRetainedValue() as? [String: String] ?? [:]
    }

    func httpResponse() -> HTTPURLResponse? {
        guard let url else { return nil }
        let version = CFHTTPMessageCopyVersion(self).takeRetainedValue() as String
        return HTTPURLResponse(
            url: url,
            statusCode: CFHTTPMessageGetResponseStatusCode(self),
            httpVersion: version,
            headerFields: allHeaderFields
        )
    }
}

extension InputStream {
    var trust: SecTrust? {
        let key = Stream.PropertyKey(kCFStreamPropertySSLPeerTrust as String)
        guard let value = property(forKey: key) as AnyObject?,
              CFGetTypeID(value) == SecTrustGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: SecTrust.self)
    }

    /// The stream connects to an IP, so the default chain validation against the URL's host
    /// would fail. The handler evaluates the certificate against the real domain instead.
    func disableCertificateChainValidation() {
        let settings: [AnyHashable: Any] = [kCFStreamSSLValidatesCertificateChain: kCFBooleanFalse as Any]
        setProperty(settings, forKey: Stream.PropertyKey(kCFStreamPropertySSLSettings as String))
    }

    func httpMessage() -> CFHTTPMessage? {
        let key = CFStreamPropertyKey(rawValue: "kCFStreamPropertyHTTPResponseHeader" as CFString)
        guard let value = CFReadStreamCopyProperty(self as CFReadStream, key),
              CFGetTypeID(value) == CFHTTPMessageGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: CFHTTPMessage.self)
    }

    /// An unopened HTTP stream that sends `request` as is.
    static func makeHTTPStream(for request: URLRequest) -> Result<InputStream, DFStreamError> {
        makeHTTPMessage(for: request).map { message in
            let factory: any HTTPReadStreamFactory.Type = DeprecatedHTTPReadStream.self
            let stream = factory.makeStream(for: message)
            let key = Stream.PropertyKey("kCFStreamPropertyHTTPAttemptPersistentConnection")
            stream.setProperty(true, forKey: key)
            return stream
        }
    }

    /// The HTTP message for `request`: its method, URL, headers and body, plus a `Host` header
    /// when the request lacks one.
    static func makeHTTPMessage(for request: URLRequest) -> Result<CFHTTPMessage, DFStreamError> {
        guard let method = request.httpMethod else { return .failure(.methodNotFound) }
        guard let url = request.url else { return .failure(.urlNotFound) }

        let message = CFHTTPMessageCreateRequest(
            kCFAllocatorDefault, method as CFString, url as CFURL, kCFHTTPVersion1_1
        ).takeRetainedValue()
        request.allHTTPHeaderFields?.forEach { field, value in
            CFHTTPMessageSetHeaderFieldValue(message, field as CFString, value as CFString)
        }
        if !request.hasHostField {
            CFHTTPMessageSetHeaderFieldValue(message, "host" as CFString, request.domain as CFString?)
        }
        if let body = request.bodyData() {
            CFHTTPMessageSetBody(message, body as CFData)
        }
        return .success(message)
    }
}

// Calling a deprecated function from a deprecated declaration does not warn, and calling that
// declaration through a protocol requirement does not either. This keeps the build warning-free
// without an Objective-C shim (legacy used the `DeprecatedAPI` package for the same purpose).
private protocol HTTPReadStreamFactory {
    static func makeStream(for message: CFHTTPMessage) -> InputStream
}

private enum DeprecatedHTTPReadStream: HTTPReadStreamFactory {
    @available(iOS, deprecated: 9.0)
    @available(macOS, deprecated: 10.11)
    static func makeStream(for message: CFHTTPMessage) -> InputStream {
        CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, message).takeRetainedValue() as InputStream
    }
}
