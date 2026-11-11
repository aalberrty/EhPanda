import EhModels

extension BanInterval {
    /// E.g. "2 days and 3 hours".
    var localizedDescription: String {
        let and = L10n.Localizable.Enum.BanInterval.Description.and
        var params: [String]
        switch self {
        case .days(let days, let hours):
            params = [Self.days(days)]
            if let hours { params += [and, Self.hours(hours)] }
        case .hours(let hours, let minutes):
            params = [Self.hours(hours)]
            if let minutes { params += [and, Self.minutes(minutes)] }
        case .minutes(let minutes, let seconds):
            params = [Self.minutes(minutes)]
            if let seconds { params += [and, Self.seconds(seconds)] }
        case .unrecognized(let content):
            params = [content]
        }
        return params.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func days(_ value: Int) -> String {
        value > 1 ? L10n.Localizable.Common.Value.days("\(value)") : L10n.Localizable.Common.Value.day("\(value)")
    }
    private static func hours(_ value: Int) -> String {
        value > 1 ? L10n.Localizable.Common.Value.hours("\(value)") : L10n.Localizable.Common.Value.hour("\(value)")
    }
    private static func minutes(_ value: Int) -> String {
        value > 1
            ? L10n.Localizable.Common.Value.minutes("\(value)") : L10n.Localizable.Common.Value.minute("\(value)")
    }
    private static func seconds(_ value: Int) -> String {
        value > 1
            ? L10n.Localizable.Common.Value.seconds("\(value)") : L10n.Localizable.Common.Value.second("\(value)")
    }
}
