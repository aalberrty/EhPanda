import Foundation
import Security

/// Turns stream events of a `DFRequest` into `DFRequestDelegate` calls. Runs on the run loop
/// the stream is scheduled on.
final class DFStreamEventHandler: NSObject {
    private weak var request: DFRequest?
    private var receivedResponse = false
    private var hasEvaluated = false

    init(request: DFRequest) {
        self.request = request
    }
}

extension DFStreamEventHandler: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        // A delegate callback may stop and release the request, and with it this handler.
        guard let request, let input = aStream as? InputStream else { return }
        withExtendedLifetime(self) {
            autoreleasepool {
                switch eventCode {
                case .hasBytesAvailable:
                    readIfHasBytesAvailable(input, request: request)
                case .endEncountered:
                    endEncountered(input, request: request)
                case .errorOccurred:
                    errorOccurred(input, request: request)
                default:
                    break
                }
            }
        }
    }
}

private extension DFStreamEventHandler {
    func readIfHasBytesAvailable(_ stream: InputStream, request: DFRequest) {
        let message = stream.httpMessage()
        guard message?.isHeaderComplete == true else { return }

        if request.request.isHTTPS, !hasEvaluated {
            guard Self.evaluate(stream.trust, domain: request.request.domain) else {
                let error = NSError(domain: "CFNetwork SSLHandshake failed", code: -9870)
                request.delegate?.dfRequest(request.request, didFailWithError: error)
                request.stop()
                return
            }
            hasEvaluated = true
        }

        if !receivedResponse, let response = message?.httpResponse() {
            receivedResponse = true
            request.delegate?.dfRequest(request, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        guard stream.hasBytesAvailable else { return }
        let data = Self.readData(from: stream)
        request.delegate?.dfRequest(request, didLoad: data)
    }

    func endEncountered(_ stream: InputStream, request: DFRequest) {
        let message = stream.httpMessage()
        guard let response = message?.httpResponse(), (300..<400).contains(response.statusCode) else {
            finish(stream, request: request)
            return
        }

        let headers = message?.allHeaderFields ?? [:]
        guard let locationKey = headers.keys.first(where: { $0.lowercased() == "location" }),
              let location = headers[locationKey],
              let url = dfRedirectURL(location: location, domainWithScheme: request.request.domainWithScheme)
        else {
            finish(stream, request: request)
            return
        }

        var redirect = URLRequest(url: url)
        redirect.httpMethod = "GET"
        request.delegate?.dfRequest(request, wasRedirectedTo: redirect, redirectResponse: response)
    }

    func finish(_ stream: InputStream, request: DFRequest) {
        if stream.streamError != nil {
            errorOccurred(stream, request: request)
        } else {
            request.delegate?.dfRequestDidFinishLoading(request)
        }
    }

    func errorOccurred(_ stream: Stream, request: DFRequest) {
        if let error = stream.streamError {
            if !request.request.urlContainsImageURL {
                let url = request.request.url?.absoluteString ?? ""
                NetworkLog.logger.error("Domain fronting stream failed for \(url, privacy: .private): \(error)")
            }
            request.delegate?.dfRequest(request.request, didFailWithError: error)
        }
        request.stop()
    }

    static func readData(from stream: InputStream) -> Data {
        let bufferSize = 16 * 1024
        var data = Data(count: bufferSize)
        let readCount = data.withUnsafeMutableBytes { buffer -> Int in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return stream.read(base, maxLength: bufferSize)
        }
        data.count = max(0, readCount)
        return data
    }

    /// Validates the server certificate against the real domain, since the stream itself
    /// connected to an IP with chain validation off.
    static func evaluate(_ serverTrust: SecTrust?, domain: String?) -> Bool {
        guard let serverTrust else { return false }
        let policy = domain.map { SecPolicyCreateSSL(true, $0 as CFString) } ?? SecPolicyCreateBasicX509()
        SecTrustSetPolicies(serverTrust, policy)

        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            NetworkLog.logger.error("Domain fronting certificate evaluation failed: \(String(describing: error))")
            return false
        }
        return true
    }
}
