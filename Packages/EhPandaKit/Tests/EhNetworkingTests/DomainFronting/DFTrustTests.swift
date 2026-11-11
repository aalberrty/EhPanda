import Foundation
import Security
import Testing
@testable import EhNetworking

/// The certificate under test is valid for `e-hentai.org` and `*.e-hentai.org` and was issued
/// by the test root.
struct DFTrustTests {
    @Test(arguments: ["e-hentai.org", "forums.e-hentai.org"])
    func acceptsTheCertificateForItsOwnNames(host: String) throws {
        #expect(TestCertificates.trustingTestRoot(try TestCertificates.makeTrust(), host))
    }

    @Test(arguments: ["exhentai.org", "e-hentai.org.example.com", "ehgt.org", "104.20.134.21", ""])
    func rejectsTheCertificateForAnyOtherName(host: String) throws {
        #expect(!TestCertificates.trustingTestRoot(try TestCertificates.makeTrust(), host))
    }

    @Test func rejectsAnIssuerTheSystemDoesNotTrust() throws {
        // The evaluation the app uses: right name, but nothing vouches for the issuer.
        #expect(!DFTrust.evaluate(try TestCertificates.makeTrust(), host: "e-hentai.org"))
    }

    @Test func rejectsAnExpiredCertificate() throws {
        let trust = try TestCertificates.makeTrust()
        SecTrustSetAnchorCertificates(trust, [TestCertificates.root] as CFArray)
        SecTrustSetVerifyDate(trust, Date(timeIntervalSince1970: 1_900_000_000) as CFDate)

        #expect(!DFTrust.evaluate(trust, host: "e-hentai.org"))
    }
}
