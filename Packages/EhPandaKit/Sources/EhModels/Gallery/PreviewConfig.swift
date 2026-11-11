import Foundation

/// How the detail page lays out previews, which determines how many fit on one page.
/// Persisted in Swift's synthesized enum form, e.g. `{"normal":{"rows":4}}`.
public enum PreviewConfig: Codable, Sendable, Hashable {
    case normal(rows: Int)
    case large(rows: Int)
}

extension PreviewConfig {
    /// Previews per page.
    public var batchSize: Int {
        switch self {
        case .normal(let rows): 10 * rows
        case .large(let rows): 5 * rows
        }
    }

    /// The 0-based preview page that holds the 1-based page `index`.
    ///
    /// The legacy app divided the index itself, which put every index that is an exact
    /// multiple of the batch size (40, 80, …) on the following preview page.
    public func pageNumber(index: Int) -> Int {
        (max(index, 1) - 1) / max(batchSize, 1)
    }

    /// The 1-based indices on the preview page that holds the 1-based page `index`.
    public func batchRange(index: Int) -> ClosedRange<Int> {
        let lowerBound = pageNumber(index: index) * batchSize + 1
        let upperBound = lowerBound + batchSize - 1
        return lowerBound...upperBound
    }
}
