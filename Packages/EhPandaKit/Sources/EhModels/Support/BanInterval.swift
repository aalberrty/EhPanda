import Foundation

/// How long the site says an IP ban lasts, as parsed from the ban page.
public enum BanInterval: Sendable, Hashable {
    case days(_: Int, hours: Int?)
    case hours(_: Int, minutes: Int?)
    case minutes(_: Int, seconds: Int?)
    case unrecognized(content: String)
}
