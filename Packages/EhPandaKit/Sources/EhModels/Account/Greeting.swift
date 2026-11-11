import Foundation

/// The daily login reward ("It is the dawn of a new day!").
public struct Greeting: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID

    public var gainedEXP: Int?
    public var gainedCredits: Int?
    public var gainedGP: Int?
    public var gainedHath: Int?
    public var updateTime: Date?

    public init(
        id: UUID = .init(),
        gainedEXP: Int? = nil,
        gainedCredits: Int? = nil,
        gainedGP: Int? = nil,
        gainedHath: Int? = nil,
        updateTime: Date? = nil
    ) {
        self.id = id
        self.gainedEXP = gainedEXP
        self.gainedCredits = gainedCredits
        self.gainedGP = gainedGP
        self.gainedHath = gainedHath
        self.updateTime = updateTime
    }

    public static let mock = Greeting(gainedEXP: 10, gainedCredits: 10000, gainedGP: 10000, gainedHath: 10)

    public var gainedNothing: Bool {
        [gainedEXP, gainedCredits, gainedGP, gainedHath].allSatisfy { $0 == nil }
    }
}
