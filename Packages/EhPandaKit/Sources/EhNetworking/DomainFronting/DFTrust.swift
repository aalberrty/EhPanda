import Foundation
import Security

/// Certificate validation for domain fronting.
///
/// The connection goes to an address, so the system would validate the certificate against
/// that address. Domain fronting validates it against the domain the request is for instead.
enum DFTrust {
    /// Whether `trust` is a valid TLS server certificate chain for `host` under the system's
    /// trust store. Blocks while it evaluates; never call it on the main thread.
    static func evaluate(_ trust: SecTrust, host: String) -> Bool {
        guard SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, host as CFString)) == errSecSuccess else {
            return false
        }
        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            let reason = error.map { CFErrorCopyDescription($0) as String } ?? "unknown"
            NetworkLog.logger.error(
                "Domain fronting: the server's certificate is not valid for \(host, privacy: .public): \(reason)"
            )
            return false
        }
        return true
    }
}
