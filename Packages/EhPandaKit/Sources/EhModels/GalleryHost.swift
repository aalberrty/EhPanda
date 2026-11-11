import Foundation

/// The two sites the app can browse. They share one account but have separate cookies.
public enum GalleryHost: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case ehentai = "E-Hentai"
    case exhentai = "ExHentai"

    public var id: String { rawValue }

    public var url: URL {
        switch self {
        case .ehentai: URL(string: "https://e-hentai.org/")!
        case .exhentai: URL(string: "https://exhentai.org/")!
        }
    }

    /// Every URL whose cookies belong to this host.
    public var cookieURLs: [URL] {
        switch self {
        case .ehentai: [url]
        case .exhentai: [url, URL(string: "https://s.exhentai.org/")!]
        }
    }

    public var abbreviation: String {
        switch self {
        case .ehentai: "eh"
        case .exhentai: "ex"
        }
    }
}
