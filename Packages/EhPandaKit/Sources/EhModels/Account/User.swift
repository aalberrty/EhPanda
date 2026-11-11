import Foundation

/// The signed-in user's profile as scraped from the site.
public struct User: Codable, Sendable, Equatable {
    public var displayName: String?
    public var avatarURL: URL?
    public var apikey: String?

    public var credits: String?
    public var galleryPoints: String?

    public var greeting: Greeting?

    /// The user's names for favorite folders 0–9.
    public var favoriteCategories: [Int: String]?

    public init(
        displayName: String? = nil,
        avatarURL: URL? = nil,
        apikey: String? = nil,
        credits: String? = nil,
        galleryPoints: String? = nil,
        greeting: Greeting? = nil,
        favoriteCategories: [Int: String]? = nil
    ) {
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.apikey = apikey
        self.credits = credits
        self.galleryPoints = galleryPoints
        self.greeting = greeting
        self.favoriteCategories = favoriteCategories
    }

    public static let empty = User()

    /// The user's own name for favorite folder `index`, or `nil` when the folder still has
    /// the site's default name (`"Favorites N"`) and should be shown localized instead.
    public func customFavoriteCategoryName(index: Int) -> String? {
        guard let name = favoriteCategories?[index], name != "Favorites \(index)" else { return nil }
        return name
    }
}
