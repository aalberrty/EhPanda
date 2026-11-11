import Foundation

/// Paging state of a gallery list.
///
/// Older list pages are numbered (`current` / `maximum`); newer ones page by the last
/// item's timestamp and only say whether a next page exists.
public struct PageNumber: Sendable, Hashable {
    public var current: Int
    public var maximum: Int
    public var lastItemTimestamp: String?
    public var isNextButtonEnabled: Bool

    public init(
        current: Int = 0,
        maximum: Int = 0,
        lastItemTimestamp: String? = nil,
        isNextButtonEnabled: Bool = false
    ) {
        self.current = current
        self.maximum = maximum
        self.lastItemTimestamp = lastItemTimestamp
        self.isNextButtonEnabled = isNextButtonEnabled
    }

    public var isSinglePage: Bool {
        current == 0 && maximum == 0
    }

    public func hasNextPage(isNumericBased: Bool = false) -> Bool {
        isNumericBased ? current < maximum : isNextButtonEnabled
    }

    public mutating func resetPages() {
        self = Self()
    }
}
