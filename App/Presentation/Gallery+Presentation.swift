import EhModels
import SwiftUI

extension Gallery {
    func color(for host: GalleryHost) -> Color {
        category.color(for: host)
    }
}
