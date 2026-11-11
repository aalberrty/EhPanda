import EhModels

extension Greeting {
    /// Each reward with its unit, e.g. `["10 EXP", "10,000 Credits"]`.
    var rewards: [String] {
        [(gainedEXP, "EXP"), (gainedCredits, "Credits"), (gainedGP, "GP"), (gainedHath, "Hath")]
            .compactMap { value, unit in value.map { "\($0.formatted(.number)) \(unit)" } }
    }

    /// E.g. "You gain 10 EXP, 10,000 Credits and 10 Hath!", or `nil` when nothing was gained.
    var gainContent: String? {
        let rewards = rewards
        guard !rewards.isEmpty else { return nil }
        let and = L10n.Localizable.Struct.Greeting.Mark.and
        let separator = L10n.Localizable.Struct.Greeting.Mark.separator
        let description = rewards.enumerated().map { offset, element in
            if offset == 0 {
                element
            } else if offset == rewards.count - 1 {
                (rewards.count > 2 ? and : separator) + element
            } else {
                separator + element
            }
        }
        .joined()
        return [L10n.Localizable.Struct.Greeting.Mark.start, description, L10n.Localizable.Struct.Greeting.Mark.end]
            .joined()
    }
}
