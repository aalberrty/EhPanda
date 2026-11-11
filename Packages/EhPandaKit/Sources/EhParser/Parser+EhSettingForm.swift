import EhModels
import Foundation
import Kanna

// MARK: Building

extension EhSettingFields {
    /// The setting, or `nil` when any required option was not found.
    func build() -> EhSetting? {
        guard !ehProfiles.filter(\.isSelected).isEmpty,
              let isCapableOfCreatingNewProfile, let capableLoadThroughHathSetting,
              let capableImageResolution, let capableSearchResultCount,
              !capableThumbnailConfigSizes.isEmpty, let capableThumbnailConfigRowCount,
              let loadThroughHathSetting, let browsingCountry, let literalBrowsingCountry,
              let imageResolution, let imageSizeWidth, let imageSizeHeight, let galleryName,
              let archiverBehavior, let displayMode, let showSearchRangeIndicator,
              let enableGalleryThumbnailSelector, disabledCategories.count == 10,
              favoriteCategories.count == 10, let favoritesSortOrder, let ratingsColor,
              let tagFilteringThreshold, let tagWatchingThreshold, let showFilteredRemovalCount,
              excludedLanguages.count == 50, let excludedUploaders, let searchResultCount,
              let thumbnailLoadTiming, let thumbnailConfigSize, let thumbnailConfigRows,
              let coverScaleFactor, let viewportVirtualWidth, let commentsSortOrder,
              let commentVotesShowTiming, let tagsSortOrder, let galleryPageNumbers
        else { return nil }

        return EhSetting(
            ehProfiles: ehProfiles.sorted(),
            isCapableOfCreatingNewProfile: isCapableOfCreatingNewProfile,
            capableLoadThroughHathSetting: capableLoadThroughHathSetting,
            capableImageResolution: capableImageResolution,
            capableSearchResultCount: capableSearchResultCount,
            capableThumbnailConfigRowCount: capableThumbnailConfigRowCount,
            capableThumbnailConfigSizes: capableThumbnailConfigSizes,
            loadThroughHathSetting: loadThroughHathSetting,
            browsingCountry: browsingCountry,
            literalBrowsingCountry: literalBrowsingCountry,
            imageResolution: imageResolution,
            imageSizeWidth: imageSizeWidth,
            imageSizeHeight: imageSizeHeight,
            galleryName: galleryName,
            archiverBehavior: archiverBehavior,
            displayMode: displayMode,
            showSearchRangeIndicator: showSearchRangeIndicator,
            enableGalleryThumbnailSelector: enableGalleryThumbnailSelector,
            disabledCategories: disabledCategories,
            favoriteCategories: favoriteCategories,
            favoritesSortOrder: favoritesSortOrder,
            ratingsColor: ratingsColor,
            tagFilteringThreshold: tagFilteringThreshold,
            tagWatchingThreshold: tagWatchingThreshold,
            showFilteredRemovalCount: showFilteredRemovalCount,
            excludedLanguages: excludedLanguages,
            excludedUploaders: excludedUploaders,
            searchResultCount: searchResultCount,
            thumbnailLoadTiming: thumbnailLoadTiming,
            thumbnailConfigSize: thumbnailConfigSize,
            thumbnailConfigRows: thumbnailConfigRows,
            coverScaleFactor: coverScaleFactor,
            viewportVirtualWidth: viewportVirtualWidth,
            commentsSortOrder: commentsSortOrder,
            commentVotesShowTiming: commentVotesShowTiming,
            tagsSortOrder: tagsSortOrder,
            galleryPageNumbering: galleryPageNumbers,
            useOriginalImages: useOriginalImages,
            useMultiplePageViewer: useMultiplePageViewer,
            multiplePageViewerStyle: multiplePageViewerStyle,
            multiplePageViewerShowThumbnailPane: multiplePageViewerShowThumbnailPane
        )
    }
}

// MARK: Form controls

/// Reads the settings form's controls by `name`.
enum FormReader {
    static func hasInput(_ node: Kanna.XMLElement, _ name: String) -> Bool {
        node.at_xpath("//input [@name='\(name)']") != nil
    }

    /// The value of the last checked radio button.
    static func int(node: Kanna.XMLElement, name: String) -> Int? {
        var value: Int?
        for link in node.xpath("//input [@name='\(name)']") where link["checked"] == "checked" {
            value = Int(link["value"] ?? "")
        }
        return value
    }

    static func enumValue<T: RawRepresentable>(node: Kanna.XMLElement, name: String) -> T? where T.RawValue == Int {
        guard let rawValue = int(node: node, name: name) else { return nil }
        return T(rawValue: rawValue)
    }

    static func string(node: Kanna.XMLElement, name: String) -> String? {
        node.at_xpath("//input [@name='\(name)']")?["value"]
    }

    /// A text field's number, or `defaultValue` when it is missing or not a number.
    static func float(node: Kanna.XMLElement, name: String, default defaultValue: Float) -> Float {
        string(node: node, name: name).flatMap(Float.init) ?? defaultValue
    }

    static func bool(node: Kanna.XMLElement, name: String) -> Bool? {
        switch string(node: node, name: name) {
        case "0": false
        case "1": true
        default: nil
        }
    }

    static func checkBoxBool(node: Kanna.XMLElement, name: String) -> Bool? {
        node.at_xpath("//input [@name='\(name)']")?["checked"] == "checked"
    }

    /// The highest option the account may pick: the largest value among enabled radios.
    static func capability<T: RawRepresentable>(node: Kanna.XMLElement, name: String) -> T? where T.RawValue == Int {
        var maxValue: Int?
        for link in node.xpath("//input [@name='\(name)']") where link["disabled"] != "disabled" {
            let value = Int(link["value"] ?? "") ?? 0
            if maxValue == nil {
                maxValue = value
            } else if maxValue ?? 0 < value {
                maxValue = value
            }
        }
        return T(rawValue: maxValue ?? 0)
    }

    /// Every option of a `select` as `(text, value, isSelected)`.
    static func selections(node: Kanna.XMLElement, name: String) -> [(String, String, Bool)] {
        guard let select = node.at_xpath("//select [@name='\(name)']")
        else { return [] }

        var selections = [(String, String, Bool)]()
        for link in select.xpath("//option") {
            guard let name = link.text,
                  let value = link["value"]
            else { continue }

            selections.append((name, value, link["selected"] == "selected"))
        }

        return selections
    }
}
