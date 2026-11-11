import Foundation

/// The H@H archive options the archive page offers for a gallery.
public struct GalleryArchive: Codable, Sendable, Hashable {
    public let hathArchives: [HathArchive]

    public init(hathArchives: [HathArchive]) {
        self.hathArchives = hathArchives
    }
}

extension GalleryArchive {
    public struct HathArchive: Codable, Sendable, Hashable, Identifiable {
        public var id: String { resolution.rawValue }

        public let resolution: ArchiveResolution
        public let fileSize: String
        /// The price exactly as the site prints it, e.g. `"Free"`, `"1,234 GP"` or `"N/A"`.
        /// The app localizes `"Free"` for display.
        public let gpPrice: String

        public init(resolution: ArchiveResolution, fileSize: String, gpPrice: String) {
            self.resolution = resolution
            self.fileSize = fileSize
            self.gpPrice = gpPrice
        }

        public var isValid: Bool {
            fileSize != "N/A" && gpPrice != "N/A"
        }
    }
}

public enum ArchiveResolution: String, Codable, Sendable, Hashable, CaseIterable {
    case x780 = "780x"
    case x980 = "980x"
    case x1280 = "1280x"
    case x1600 = "1600x"
    case x2400 = "2400x"
    case original = "Original"

    /// The value the archiver form submits for this resolution.
    public var parameter: String {
        switch self {
        case .original: "org"
        default: String(rawValue.dropLast())
        }
    }
}
