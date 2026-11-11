import EhModels
import Foundation

// Requests that are not about one gallery or the account.
extension EhRequestBuilder {
    /// Always e-hentai.org's news page, the only place that shows the daily greeting.
    public func greeting() -> URLRequest {
        RequestEncoding.get(EhEndpoints.news)
    }

    /// GitHub's latest-release API for the language's tag translation database; its
    /// `published_at` tells whether the local copy is out of date.
    public func tagTranslatorRelease(language: TranslatableLanguage) -> URLRequest {
        RequestEncoding.get(EhEndpoints.tagTranslatorRelease(language: language))
    }

    /// The database asset of the language's latest release.
    public func tagTranslatorDownload(language: TranslatableLanguage) -> URLRequest {
        RequestEncoding.get(EhEndpoints.tagTranslatorDownload(language: language))
    }

    /// A plain GET of any URL (legacy `DataRequest`).
    public func data(url: URL) -> URLRequest {
        RequestEncoding.get(url)
    }
}

extension EhEndpoints {
    /// `https://api.github.com/repos/<repo>/releases/latest`
    public static func tagTranslatorRelease(language: TranslatableLanguage) -> URL {
        githubAPI.appendingPathComponent("\(language.repoName)/releases/latest")
    }

    /// `https://github.com/<repo>/releases/latest/download/<file>`
    public static func tagTranslatorDownload(language: TranslatableLanguage) -> URL {
        github.appendingPathComponent("\(language.repoName)/releases/latest/download/\(language.remoteFilename)")
    }
}
