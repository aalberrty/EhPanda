import Dependencies
import Foundation

/// The pasteboard change count the app last looked at, so a copied link is offered only once.
///
/// Kept under legacy's `"clipboardChangeCount"` `UserDefaults` key, so a link already handled by
/// the old app is not offered again after the upgrade.
public struct ClipboardChangeCountStore: Sendable {
    public var load: @Sendable () -> Int?
    public var save: @Sendable (Int) -> Void

    public init(load: @escaping @Sendable () -> Int?, save: @escaping @Sendable (Int) -> Void) {
        self.load = load
        self.save = save
    }

    static let key = "clipboardChangeCount"

    /// A store that keeps the count in memory only.
    public static func inMemory(_ initial: Int? = nil) -> ClipboardChangeCountStore {
        let value = LockIsolated(initial)
        return ClipboardChangeCountStore(load: { value.value }, save: { value.setValue($0) })
    }
}

extension ClipboardChangeCountStore: DependencyKey {
    public static let liveValue = ClipboardChangeCountStore(
        load: { UserDefaults.standard.object(forKey: key) as? Int },
        save: { UserDefaults.standard.set($0, forKey: key) }
    )

    public static var testValue: ClipboardChangeCountStore { .inMemory() }
    public static var previewValue: ClipboardChangeCountStore { .inMemory() }
}

extension DependencyValues {
    public var clipboardChangeCountStore: ClipboardChangeCountStore {
        get { self[ClipboardChangeCountStore.self] }
        set { self[ClipboardChangeCountStore.self] = newValue }
    }
}
