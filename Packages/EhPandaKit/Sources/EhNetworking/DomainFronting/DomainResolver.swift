/// Fixed IP addresses for the site's domains, so domain fronting can connect without DNS
/// and without sending the domain name in the TLS handshake.
enum DomainResolver {
    /// A random address for `domain`, or `nil` when the domain is not known.
    static func resolve(domain: String) -> String? {
        ResolvableDomain(rawValue: domain)?.ipPool.randomElement()
    }
}

enum ResolvableDomain: String, CaseIterable {
    case ehgt = "ehgt.org"
    case ehgt0 = "gt0.ehgt.org"
    case ehgt1 = "gt1.ehgt.org"
    case ehgt2 = "gt2.ehgt.org"
    case ehgt3 = "gt3.ehgt.org"
    case ehgtul = "ul.ehgt.org"
    case ehentai = "e-hentai.org"
    case exhentai = "exhentai.org"
    case repo = "repo.e-hentai.org"
    case forums = "forums.e-hentai.org"
    case github = "raw.githubusercontent.com"

    var ipPool: [String] {
        switch self {
        case .ehgt, .ehgt0, .ehgt1, .ehgt2, .ehgt3:
            ["37.48.89.44", "81.171.10.48", "178.162.139.24", "178.162.140.212"]
        case .ehgtul:
            ["94.100.24.82", "94.100.24.72"]
        case .ehentai:
            ["104.20.134.21", "104.20.135.21", "172.67.0.127"]
        case .exhentai:
            [
                "178.175.128.252", "178.175.129.252", "178.175.129.254",
                "178.175.128.254", "178.175.132.20", "178.175.132.22"
            ]
        case .repo:
            ["94.100.28.57", "94.100.29.73"]
        case .forums:
            ["94.100.18.243"]
        case .github:
            ["151.101.0.133", "151.101.64.133", "151.101.128.133", "151.101.192.133"]
        }
    }
}
