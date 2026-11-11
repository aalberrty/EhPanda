import Foundation

/// Access to the files under `Sources/EhTestSupport/Fixtures`.
public enum Fixture {
    public enum FixtureError: Error {
        case missing(String)
    }

    /// Returns the URL of a fixture, given its path relative to the `Fixtures` directory,
    /// for example `"Parser/List/FrontPageMinimalList.html"`.
    public static func url(_ relativePath: String) throws -> URL {
        let url = Bundle.module.resourceURL?
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(relativePath)
        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureError.missing(relativePath)
        }
        return url
    }

    public static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: url(relativePath))
    }

    public static func string(_ relativePath: String) throws -> String {
        try String(contentsOf: url(relativePath), encoding: .utf8)
    }
}
