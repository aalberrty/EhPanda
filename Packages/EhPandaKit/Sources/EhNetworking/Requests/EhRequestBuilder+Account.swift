import EhModels
import Foundation

// Account and site settings.
extension EhRequestBuilder {
    /// Always the forum on forums.e-hentai.org. Values are encoded with the legacy form
    /// rules, so `&`, `=` and `+` in a username or password are sent unescaped.
    public func login(username: String, password: String) -> URLRequest {
        RequestEncoding.postForm(EhEndpoints.login, fields: [
            ("b", "d"),
            ("bt", "1-1"),
            ("CookieDate", "1"),
            ("UserName", username),
            ("PassWord", password),
            ("ipb_login_submit", "Login!")
        ])
    }

    /// Always exhentai.org: loading its front page with e-hentai cookies makes the site
    /// issue the `igneous` cookie that unlocks it.
    public func igneous() -> URLRequest {
        RequestEncoding.get(EhEndpoints.exhentai)
    }

    /// The settings page, parsed for the favorites category names.
    public func favoriteCategories() -> URLRequest {
        RequestEncoding.get(uConfigURL)
    }

    /// The settings page, parsed for the app's own profile.
    public func verifyEhProfile() -> URLRequest {
        RequestEncoding.get(uConfigURL)
    }

    public func ehSetting() -> URLRequest {
        RequestEncoding.get(uConfigURL)
    }

    /// Creates, deletes, renames or selects a settings profile. Only the fields given are
    /// sent; `set` is the profile's value.
    public func ehProfile(action: EhProfileAction? = nil, name: String? = nil, set: Int? = nil) -> URLRequest {
        var fields = [(String, String)]()
        if let action {
            fields.append(("profile_action", action.rawValue))
        }
        if let name {
            fields.append(("profile_name", name))
        }
        if let set {
            fields.append(("profile_set", String(set)))
        }
        return RequestEncoding.postForm(uConfigURL, fields: fields)
    }

    public func submitEhSettingChanges(_ ehSetting: EhSetting) -> URLRequest {
        RequestEncoding.postForm(uConfigURL, fields: EhSettingForm.fields(for: ehSetting))
    }
}
