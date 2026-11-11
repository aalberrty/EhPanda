/// Names of the site cookies the app reads or writes.
public enum CookieName {
    public static let yay = "yay"
    /// `nw=1` skips the offensive-content warning page.
    public static let ignoreOffensive = "nw"
    public static let selectedProfile = "sp"
    public static let skipServer = "skipserver"

    public static let igneous = "igneous"
    public static let ipbMemberId = "ipb_member_id"
    public static let ipbPassHash = "ipb_pass_hash"

    /// The three cookies that make up a login.
    static let credentials = [igneous, ipbMemberId, ipbPassHash]
}

/// Special cookie values the site uses.
public enum CookieValueConstant {
    public static let null = "null"
    public static let expired = "expired"
    /// The `igneous` value ExHentai hands out to accounts without access.
    public static let mystery = "mystery"
}
