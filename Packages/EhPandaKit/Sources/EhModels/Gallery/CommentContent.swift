import Foundation

/// One run of a comment body: text, a link, or one or two (linked) images.
public struct CommentContent: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public let type: CommentContentType
    public var text: String?
    public var link: URL?
    public var imgURL: URL?

    public var secondLink: URL?
    public var secondImgURL: URL?

    public init(
        id: UUID = .init(),
        type: CommentContentType,
        text: String? = nil,
        link: URL? = nil,
        imgURL: URL? = nil,
        secondLink: URL? = nil,
        secondImgURL: URL? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.link = link
        self.imgURL = imgURL
        self.secondLink = secondLink
        self.secondImgURL = secondImgURL
    }
}

public enum CommentContentType: Int, Codable, Sendable, Hashable {
    case singleImg
    case doubleImg
    case linkedImg
    case doubleLinkedImg

    case plainText
    case linkedText

    case singleLink
}
