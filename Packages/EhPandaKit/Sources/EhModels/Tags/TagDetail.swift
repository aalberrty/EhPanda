import Foundation

/// What the tag detail sheet shows for one translated tag.
public struct TagDetail: Sendable, Hashable {
    public let title: String
    public let description: String
    public let imageURLs: [URL]
    public let links: [URL]

    public init(title: String, description: String, imageURLs: [URL], links: [URL]) {
        self.title = title
        self.description = description
        self.imageURLs = imageURLs
        self.links = links
    }
}
