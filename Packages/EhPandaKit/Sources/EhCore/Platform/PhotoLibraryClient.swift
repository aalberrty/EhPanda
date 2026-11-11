import Dependencies
import Foundation

/// Saving images to the user's photo library.
public struct PhotoLibraryClient: Sendable {
    /// Saves encoded image bytes (static or animated GIF) as a new photo.
    /// Returns `false` when access is denied or the save fails.
    public var saveImage: @Sendable (Data) async -> Bool

    public init(saveImage: @escaping @Sendable (Data) async -> Bool) {
        self.saveImage = saveImage
    }
}

extension PhotoLibraryClient: TestDependencyKey {
    public static let testValue = PhotoLibraryClient(
        saveImage: unimplemented("PhotoLibraryClient.saveImage", placeholder: false)
    )

    public static let previewValue = PhotoLibraryClient(saveImage: { _ in true })
}

extension DependencyValues {
    public var photoLibraryClient: PhotoLibraryClient {
        get { self[PhotoLibraryClient.self] }
        set { self[PhotoLibraryClient.self] = newValue }
    }
}
