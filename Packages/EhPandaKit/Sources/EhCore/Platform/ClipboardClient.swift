import Dependencies
import Foundation

/// The system pasteboard.
///
/// Detecting a newly copied gallery link is a model decision: the model remembers the last
/// ``changeCount`` it handled and only reads ``url`` when the count has moved on.
public struct ClipboardClient: Sendable {
    /// The pasteboard's change count. It increases every time any app changes the pasteboard.
    public var changeCount: @MainActor @Sendable () -> Int
    /// The URL on the pasteboard, or the pasteboard text if it parses as a URL.
    public var url: @MainActor @Sendable () -> URL?
    public var copyText: @MainActor @Sendable (String) -> Void
    /// Copies encoded image bytes. The format is read from the bytes, so GIF data stays animated.
    public var copyImage: @Sendable (Data) async -> Void

    public init(
        changeCount: @escaping @MainActor @Sendable () -> Int,
        url: @escaping @MainActor @Sendable () -> URL?,
        copyText: @escaping @MainActor @Sendable (String) -> Void,
        copyImage: @escaping @Sendable (Data) async -> Void
    ) {
        self.changeCount = changeCount
        self.url = url
        self.copyText = copyText
        self.copyImage = copyImage
    }
}

extension ClipboardClient: TestDependencyKey {
    public static let testValue = ClipboardClient(
        changeCount: unimplemented("ClipboardClient.changeCount", placeholder: 0),
        url: unimplemented("ClipboardClient.url", placeholder: nil),
        copyText: unimplemented("ClipboardClient.copyText"),
        copyImage: unimplemented("ClipboardClient.copyImage")
    )

    public static let previewValue = ClipboardClient(
        changeCount: { 0 },
        url: { nil },
        copyText: { _ in },
        copyImage: { _ in }
    )
}

extension DependencyValues {
    public var clipboardClient: ClipboardClient {
        get { self[ClipboardClient.self] }
        set { self[ClipboardClient.self] = newValue }
    }
}
