import EhModels
import SwiftUI

extension GalleryTag.Content {
    /// Text colour for a highlighted tag, chosen for contrast with `backgroundColor`.
    var textColor: Color? {
        backgroundColor.map { $0.isLight ? .secondary : .white }
    }
}
