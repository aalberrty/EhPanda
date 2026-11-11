import Foundation

/// Whether a gallery is listed publicly. Persisted in Swift's synthesized enum form:
/// `{"yes":{}}` or `{"no":{"reason":"Expunged"}}`.
public enum GalleryVisibility: Codable, Sendable, Hashable {
    case yes
    case no(reason: String)
}
