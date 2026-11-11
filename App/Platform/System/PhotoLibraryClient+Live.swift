import Dependencies
import EhCore
import Photos

extension PhotoLibraryClient: @retroactive DependencyKey {
    // Adding the original bytes as a resource keeps GIFs animated and avoids re-encoding.
    // Add-only access is requested by the system on first use.
    nonisolated public static let liveValue = PhotoLibraryClient(
        saveImage: { data in
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
                }
                return true
            } catch {
                return false
            }
        }
    )
}
