import EhModels
import Foundation

/// One `UserDefaults` key per `Setting` field. The raw value is the field's name.
///
/// Keys are `"settings.<field>"`, except `galleryHost`, which keeps the bare `"galleryHost"`
/// key the legacy app already mirrored the host into, so an upgraded install keeps its host
/// and code off the main actor can read it (see `GalleryHostProvider`).
enum SettingKey: String, CaseIterable, Sendable {
    // Account
    case galleryHost, showsNewDawnGreeting
    // General
    case enablesTagsExtension, translatesTags, showsTagsSearchSuggestion, showsImagesInTags
    case redirectsLinksToSelectedHost, detectsLinksFromClipboard, backgroundBlurRadius, autoLockPolicy
    // Appearance
    case listDisplayMode, preferredColorScheme, accentColor, appIconType
    case showsTagsInList, listTagsNumberMaximum, displaysJapaneseTitle
    // Reading
    case readingDirection, prefetchLimit, enablesLandscape, enablesDualPageMode, exceptCover
    case contentDividerHeight, maximumScaleFactor, doubleTapScaleFactor
    // Laboratory
    case bypassesSNIFiltering

    var name: String {
        self == .galleryHost ? "galleryHost" : "settings.\(rawValue)"
    }
}

/// A setting value stored as a property-list object: numbers, booleans and strings as
/// themselves, enums as their raw value, colours as `[red, green, blue]`.
protocol PreferenceValue: Equatable, Sendable {
    init?(propertyListValue: Any)
    var propertyListValue: Any { get }
}

extension Bool: PreferenceValue {
    init?(propertyListValue: Any) {
        guard let value = propertyListValue as? Bool else { return nil }
        self = value
    }
    var propertyListValue: Any { self }
}

extension Int: PreferenceValue {
    init?(propertyListValue: Any) {
        guard let value = propertyListValue as? Int else { return nil }
        self = value
    }
    var propertyListValue: Any { self }
}

extension Double: PreferenceValue {
    init?(propertyListValue: Any) {
        guard let value = propertyListValue as? Double, value.isFinite else { return nil }
        self = value
    }
    var propertyListValue: Any { self }
}

extension String: PreferenceValue {
    init?(propertyListValue: Any) {
        guard let value = propertyListValue as? String else { return nil }
        self = value
    }
    var propertyListValue: Any { self }
}

extension PreferenceValue where Self: RawRepresentable, RawValue: PreferenceValue {
    init?(propertyListValue: Any) {
        guard let rawValue = RawValue(propertyListValue: propertyListValue) else { return nil }
        self.init(rawValue: rawValue)
    }
    var propertyListValue: Any { rawValue.propertyListValue }
}

extension GalleryHost: PreferenceValue {}
extension AutoLockPolicy: PreferenceValue {}
extension ListDisplayMode: PreferenceValue {}
extension PreferredColorScheme: PreferenceValue {}
extension AppIconType: PreferenceValue {}
extension ReadingDirection: PreferenceValue {}

extension RGBColor: PreferenceValue {
    init?(propertyListValue: Any) {
        // No range check: colours picked in extended sRGB can fall slightly outside 0...1.
        guard let components = propertyListValue as? [Double], components.count == 3,
              components.allSatisfy(\.isFinite)
        else { return nil }
        self.init(red: components[0], green: components[1], blue: components[2])
    }
    var propertyListValue: Any { [red, green, blue] }
}

extension PreferenceStorage {
    /// The stored value for `key`, or `fallback` when it is missing or not a valid value.
    func value<Value: PreferenceValue>(_ key: SettingKey, fallback: Value) -> Value {
        defaults.object(forKey: key.name).flatMap(Value.init(propertyListValue:)) ?? fallback
    }

    func set<Value: PreferenceValue>(_ value: Value, for key: SettingKey) {
        defaults.set(value.propertyListValue, forKey: key.name)
    }

    func contains(_ key: SettingKey) -> Bool {
        contains(key.name)
    }
}
