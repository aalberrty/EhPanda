import EhModels
import Foundation
import Kanna

// MARK: User

extension Parser {
    /// The display name and forum avatar from a forum profile page.
    public static func parseUserInfo(doc: HTMLDocument) throws -> User {
        var displayName: String?
        var avatarURL: URL?

        for ipbLink in doc.xpath("//table [@class='ipbtable']") {
            guard let profileName = ipbLink.at_xpath("//div [@id='profilename']")?.text
            else { continue }

            displayName = profileName

            for imgLink in ipbLink.xpath("//img") {
                guard let imgURLString = imgLink["src"],
                      imgURLString.contains("forums.e-hentai.org/uploads"),
                      let imgURL = URL(string: imgURLString)
                else { continue }

                avatarURL = imgURL
            }
        }
        if displayName != nil {
            return User(displayName: displayName, avatarURL: avatarURL)
        } else {
            throw AppError.parseFailed
        }
    }

    /// The user's favorite folder names from the settings page, keyed by folder index 0–9.
    public static func parseFavoriteCategories(doc: HTMLDocument) throws -> [Int: String] {
        var favoriteCategories = [Int: String]()

        for link in doc.xpath("//div [@id='favsel']") {
            for inputLink in link.xpath("//input") {
                guard let name = inputLink["name"],
                      let value = inputLink["value"],
                      let type = FavoritesType(rawValue: name)
                else { continue }

                favoriteCategories[type.index] = value
            }
        }

        if !favoriteCategories.isEmpty {
            return favoriteCategories
        } else {
            throw AppError.parseFailed
        }
    }

    /// Whether the settings page lists the app's own profile, and its value.
    public static func parseProfileIndex(doc: HTMLDocument) throws -> VerifyEhProfileResponse {
        var profileNotFound = true
        var profileValue: Int?

        let selector = doc.at_xpath("//select [@name='profile_set']")
        let options = selector?.xpath("//option")

        guard let options = options, options.count >= 1
        else { throw AppError.parseFailed }

        for link in options where EhSetting.verifyEhPandaProfileName(with: link.text) {
            profileNotFound = false
            profileValue = Int(link["value"] ?? "")
        }

        return .init(profileValue: profileValue, isProfileNotFound: profileNotFound)
    }
}
