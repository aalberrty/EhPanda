import Dependencies
import Foundation

/// The three lists of the Library tab, in the order of its segmented control.
nonisolated public enum LibrarySegment: String, CaseIterable, Hashable, Sendable {
    case favorites
    case watched
    case history

    /// Favorites and Watched are the account's lists on the site; History is kept on the device.
    public var requiresLogin: Bool {
        switch self {
        case .favorites, .watched: true
        case .history: false
        }
    }
}

/// The Library segment used last, so the tab opens where the user left it.
nonisolated public struct LibrarySegmentStore: Sendable {
    public var load: @Sendable () -> LibrarySegment?
    public var save: @Sendable (LibrarySegment) -> Void

    public init(
        load: @escaping @Sendable () -> LibrarySegment?, save: @escaping @Sendable (LibrarySegment) -> Void
    ) {
        self.load = load
        self.save = save
    }

    static let key = "librarySegment"

    /// A store that keeps the segment in memory only.
    public static func inMemory(_ initial: LibrarySegment? = nil) -> LibrarySegmentStore {
        let value = LockIsolated(initial)
        return LibrarySegmentStore(load: { value.value }, save: { value.setValue($0) })
    }
}

nonisolated extension LibrarySegmentStore: DependencyKey {
    // A plain string: reading it on the main actor costs no decoding.
    public static let liveValue = LibrarySegmentStore(
        load: { UserDefaults.standard.string(forKey: key).flatMap(LibrarySegment.init(rawValue:)) },
        save: { UserDefaults.standard.set($0.rawValue, forKey: key) }
    )

    public static var testValue: LibrarySegmentStore { .inMemory() }
    public static var previewValue: LibrarySegmentStore { .inMemory() }
}

nonisolated extension DependencyValues {
    public var librarySegmentStore: LibrarySegmentStore {
        get { self[LibrarySegmentStore.self] }
        set { self[LibrarySegmentStore.self] = newValue }
    }
}
