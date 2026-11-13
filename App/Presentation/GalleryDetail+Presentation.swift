import EhModels
import Foundation

extension GalleryDetail {
    /// "183.3 MiB". The site gives at most two decimals; the stored `Float` would otherwise
    /// print as 183.300003.
    var formattedSize: String {
        sizeCount.formatted(.number.precision(.fractionLength(0...2))) + " " + sizeType
    }
}
