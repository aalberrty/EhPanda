import Foundation
import Security
@testable import EhNetworking

/// A throwaway certificate authority and the server identity it issued for `e-hentai.org` and
/// `*.e-hentai.org`, so tests can run a TLS listener on loopback.
///
/// Nothing trusts this root: to the system trust store the identity is what an impostor on one
/// of the hard-coded addresses would present. Tests that need it accepted say so with
/// `trustingTestRoot`.
///
/// Made with LibreSSL 3.3.6 (P-256 keys, SHA-256 signatures):
///
///     openssl req -new -x509 -key ca.key -days 7300 -out ca.crt        # CN=EhPanda Test Root, CA:TRUE
///     openssl x509 -req -in leaf.csr -CA ca.crt -CAkey ca.key -days 820 -out leaf.crt
///                                                                      # CN=e-hentai.org, serverAuth,
///                                                                      # SAN e-hentai.org, *.e-hentai.org
///     openssl pkcs12 -export -inkey leaf.key -in leaf.crt -passout pass:test -out leaf.p12
enum TestCertificates {
    /// A moment inside the leaf's lifetime (2026-11-11 to 2029-02-08; Apple accepts at most 825
    /// days for a TLS server certificate), so the tests do not expire with it.
    static let verifyDate = Date(timeIntervalSince1970: 1_800_000_000)

    static let root = certificate(rootDER)
    static let leaf = certificate(leafDER)

    /// The leaf with its private key, kept in memory only (never in a keychain).
    static func makeIdentity() -> SecIdentity {
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: "test",
            kSecImportToMemoryOnly as String: true
        ]
        var items: CFArray?
        let status = SecPKCS12Import(data(leafPKCS12) as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess,
              let first = (items as? [[String: Any]])?.first,
              let identity = first[kSecImportItemIdentity as String]
        else { fatalError("The test identity could not be imported (status \(status))") }
        // The dictionary's value is documented to be a `SecIdentity`.
        return identity as! SecIdentity
    }

    /// The production evaluation, with the test root as the only anchor and the clock set inside
    /// the test certificate's lifetime.
    static let trustingTestRoot: DFLoader.EvaluateTrust = { trust, host in
        SecTrustSetAnchorCertificates(trust, [root] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)
        SecTrustSetVerifyDate(trust, verifyDate as CFDate)
        return DFTrust.evaluate(trust, host: host)
    }

    /// A trust object for the leaf as a server would present it, not yet evaluated.
    static func makeTrust() throws -> SecTrust {
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates([leaf] as CFArray, SecPolicyCreateBasicX509(), &trust)
        guard status == errSecSuccess, let trust else { throw CocoaError(.coderInvalidValue) }
        return trust
    }

    private static func data(_ base64: String) -> Data {
        Data(base64Encoded: base64, options: .ignoreUnknownCharacters)!
    }

    private static func certificate(_ base64: String) -> SecCertificate {
        SecCertificateCreateWithData(nil, data(base64) as CFData)!
    }

    private static let rootDER = """
        MIIBcTCCARegAwIBAgIJAKOJqY5sSLrbMAoGCCqGSM49BAMCMBwxGjAYBgNVBAMMEUVoUGFuZGEg
        VGVzdCBSb290MB4XDTI2MTExMTA3MjAxOFoXDTQ2MTEwNjA3MjAxOFowHDEaMBgGA1UEAwwRRWhQ
        YW5kYSBUZXN0IFJvb3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAS0nEwnIP6hcTWfMx5XNhHx
        7tcJqV/y33CxnNywA4PyuMbniwRxFQN5u9a9IoIyQSj1I5PHECeZHgSLb/qZRN2xo0IwQDAPBgNV
        HRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUqzLbE6W76MSxsAfcD8/vXPM2
        IwcwCgYIKoZIzj0EAwIDSAAwRQIhAKHZrCZfjfmRYreZlVSN8EoEjOBhEpPs5uV/+HP3JVEMAiBO
        h38uZKur6G4mo4OwQUDwPu1SOpngvooP76OLHLycsQ==
        """

    private static let leafDER = """
        MIIByjCCAXCgAwIBAgIJAOi0m193y/KzMAoGCCqGSM49BAMCMBwxGjAYBgNVBAMMEUVoUGFuZGEg
        VGVzdCBSb290MB4XDTI2MTExMTA3MjAxOVoXDTI5MDIwODA3MjAxOVowFzEVMBMGA1UEAwwMZS1o
        ZW50YWkub3JnMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE4+XD5XJTWqcQ2nXfUVLQVp88jRXk
        qwctplJIuEjaQKYWxTq5yd54vLhKlbmRS4oLSxvB6bpgG9FIAdhFp5t/aaOBnzCBnDAMBgNVHRMB
        Af8EAjAAMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDATAnBgNVHREEIDAeggxl
        LWhlbnRhaS5vcmeCDiouZS1oZW50YWkub3JnMB0GA1UdDgQWBBRSQqgdc+U/M5gV9aBrZWzpt3tQ
        +DAfBgNVHSMEGDAWgBSrMtsTpbvoxLGwB9wPz+9c8zYjBzAKBggqhkjOPQQDAgNIADBFAiEAodD8
        8UDf7RTi1n9GraPqC5ic+U25RspbRsfwEOoARPsCIBjbcy7DbLMGOXm6lVNgc56C/eOv+pEGt9r0
        RQz2cb6j
        """

    private static let leafPKCS12 = """
        MIIEOQIBAzCCA/8GCSqGSIb3DQEHAaCCA/AEggPsMIID6DCCAqcGCSqGSIb3DQEHBqCCApgwggKU
        AgEAMIICjQYJKoZIhvcNAQcBMBwGCiqGSIb3DQEMAQYwDgQIWZoiS2OUgtcCAggAgIICYOSEOZMw
        CQawFoHWN3c8l/+Fjg3LPO1n2wUBdStdIibJR51VJRg1PBzdeqxSrqc+pUgJ/FnvBdcf0ws/mvOz
        vFui7I5yyHZEGVLGgjYdcnzys0uit8ecpamLDTgaMCv1kcxpL1A7d1c9f6NSLdrX9qpzi82T0D12
        BQ7l833eGXUxicJx8TTXOGbgXpvYplSpFnqDq7gENEFl33N4xney3JvOuFVcEF2PCdVctt3P/lil
        H1mVbNqQd6bFose9se9F59uuy7iLCWZFk8IMJ5YHvSwamq9wP4T2IWSpt8akAwMf7x21X26c5l3z
        SFzd1EEAVD9LIcY7IPKgxSAmDvHdWr4UEDjOOTTSHVnNOud+OlFAUNwP4ZrbAg+2+tfXtcfBcH8M
        qCjP7BiRdosKWR0asxFrSKc4n3rKSwwPW+7DDxFqfMb8eC6VUiMfhpq7yvArll5L0gG40vZE0t5/
        HyUJu5urYnkrPFT9CDD97fxeEsmh1aiubXMkENik5E/2/E1+YyrLuixrtnV0J1eG6rUiPVCkVBKn
        /hNPyu+fVFtceDLTyTKQS3VDh7YcZqT0smSx03Mh3oZ6QBNsy1Vlm93uUgeIEiqtn2ShMzYPqale
        4Fb5edZl4UbSJZoFVNL1tEJRrdutV2ZJFmaB3Q69CDD7oZruq6HhWJ3yhcEf2nL9jNod5WVZpR7j
        /852Xr6p3D+sZ2ZDkMH3RJMCjGIzXancBAAb+XNBEbBAgjJeaSLHAEgao/duqNOnLxqmQel70q5F
        ZrkuaKpK4uSXPci1N4tW30jgEqCO4ggce02lFsDHASPgMIIBOQYJKoZIhvcNAQcBoIIBKgSCASYw
        ggEiMIIBHgYLKoZIhvcNAQwKAQKggbQwgbEwHAYKKoZIhvcNAQwBAzAOBAg+GGlqoq5HLAICCAAE
        gZBAgq2EQQrdZ68IhiKtgdEP7lSwaZriDrH4R5EJ0D62Qhk1czhaZSOsC3MdnBSTxv43PMj0AoF5
        mPrFxk5JFLi+iSmspnV369ZR3s2WUXXEmQqt/629cHmcCEIiU95ZRwBNWUTOCP/W9kAyAbNM/fhM
        f3JkR5tr4S0OvvTp1bT6ngeRBstlllcfZCCTfabKXSYxWDAjBgkqhkiG9w0BCRUxFgQUu+XYWkAq
        YNP4x5wZgjKJQxcX8FgwMQYJKoZIhvcNAQkUMSQeIgBlAC0AaABlAG4AdABhAGkALgBvAHIAZwAg
        AHQAZQBzAHQwMTAhMAkGBSsOAwIaBQAEFDXz0eokPV2yHin92s0bm79lzgBPBAh0+Jho3/0/CAIC
        CAA=
        """
}
