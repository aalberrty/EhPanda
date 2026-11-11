import EhModels
import Foundation
import Kanna

// MARK: EhSetting

extension Parser {
    /// Parses the site settings page (`uconfig.php`).
    public static func parseEhSetting(doc: HTMLDocument) throws -> EhSetting {
        var tmpForm: Kanna.XMLElement?
        for link in doc.xpath("//form [@method='post']") where link["id"] == nil {
            tmpForm = link
        }
        guard let profileOuter = doc.at_xpath("//div [@id='profile_outer']"),
              let form = tmpForm else { throw AppError.parseFailed }

        var fields = EhSettingFields()
        fields.parseProfiles(profileOuter: profileOuter)
        for optouter in form.xpath("//div [@class='optouter']") {
            fields.parseImageOptions(optouter: optouter)
            fields.parseGalleryOptions(optouter: optouter)
            fields.parseFilterOptions(optouter: optouter)
            fields.parseThumbnailOptions(optouter: optouter)
            fields.parseViewerOptions(optouter: optouter)
        }
        guard let ehSetting = fields.build() else { throw AppError.parseFailed }
        return ehSetting
    }
}

/// The settings found so far. Each option is read by exactly one of the `parse…` methods.
struct EhSettingFields {
    var ehProfiles = [EhProfile]()
    var isCapableOfCreatingNewProfile: Bool?
    var capableLoadThroughHathSetting: EhSetting.LoadThroughHathSetting?
    var capableImageResolution: EhSetting.ImageResolution?
    var capableSearchResultCount: EhSetting.SearchResultCount?
    var capableThumbnailConfigSizes = [EhSetting.ThumbnailSize]()
    var capableThumbnailConfigRowCount: EhSetting.ThumbnailRowCount?
    var loadThroughHathSetting: EhSetting.LoadThroughHathSetting?
    var browsingCountry: EhSetting.BrowsingCountry?
    var imageResolution: EhSetting.ImageResolution?
    var imageSizeWidth: Float?
    var imageSizeHeight: Float?
    var galleryName: EhSetting.GalleryName?
    var literalBrowsingCountry: String?
    var archiverBehavior: EhSetting.ArchiverBehavior?
    var displayMode: EhSetting.DisplayMode?
    var showSearchRangeIndicator: Bool?
    var enableGalleryThumbnailSelector: Bool?
    var disabledCategories = [Bool]()
    var favoriteCategories = [String]()
    var favoritesSortOrder: EhSetting.FavoritesSortOrder?
    var ratingsColor: String?
    var tagFilteringThreshold: Float?
    var tagWatchingThreshold: Float?
    var showFilteredRemovalCount: Bool?
    var excludedLanguages = [Bool]()
    var excludedUploaders: String?
    var searchResultCount: EhSetting.SearchResultCount?
    var thumbnailLoadTiming: EhSetting.ThumbnailLoadTiming?
    var thumbnailConfigSize: EhSetting.ThumbnailSize?
    var thumbnailConfigRows: EhSetting.ThumbnailRowCount?
    var coverScaleFactor: Float?
    var viewportVirtualWidth: Float?
    var commentsSortOrder: EhSetting.CommentsSortOrder?
    var commentVotesShowTiming: EhSetting.CommentVotesShowTiming?
    var tagsSortOrder: EhSetting.TagsSortOrder?
    var galleryPageNumbers: EhSetting.GalleryPageNumbering?
    var useOriginalImages: Bool?
    var useMultiplePageViewer: Bool?
    var multiplePageViewerStyle: EhSetting.MultiplePageViewerStyle?
    var multiplePageViewerShowThumbnailPane: Bool?

    mutating func parseProfiles(profileOuter: Kanna.XMLElement) {
        ehProfiles = FormReader.selections(node: profileOuter, name: "profile_set")
            .compactMap { name, value, isSelected in
                guard let value = Int(value) else { return nil }
                return EhProfile(value: value, name: name, isSelected: isSelected)
            }

        for button in profileOuter.xpath("//input [@type='button']") {
            if button["value"] == "Create New" {
                isCapableOfCreatingNewProfile = true
                break
            } else {
                isCapableOfCreatingNewProfile = false
            }
        }
    }

    mutating func parseImageOptions(optouter: Kanna.XMLElement) {
        if FormReader.hasInput(optouter, "uh") {
            loadThroughHathSetting = FormReader.enumValue(node: optouter, name: "uh")
            capableLoadThroughHathSetting = FormReader.capability(node: optouter, name: "uh")
        }
        if optouter.at_xpath("//select [@name='co']") != nil {
            var value = FormReader.selections(node: optouter, name: "co").filter(\.2).first?.1

            if value == "" { value = "-" }
            browsingCountry = EhSetting.BrowsingCountry(rawValue: value ?? "")

            if let pText = optouter.at_xpath("//p")?.text,
               let rangeA = pText.range(of: "You appear to be browsing the site from "),
               let rangeB = pText.range(of: " or use a VPN or proxy in this country"),
               rangeA.upperBound <= rangeB.lowerBound
            {
                literalBrowsingCountry = String(pText[rangeA.upperBound..<rangeB.lowerBound])
            }
        }
        if FormReader.hasInput(optouter, "xr") {
            imageResolution = FormReader.enumValue(node: optouter, name: "xr")
            capableImageResolution = FormReader.capability(node: optouter, name: "xr")
        }
        if FormReader.hasInput(optouter, "rx") {
            imageSizeWidth = FormReader.float(node: optouter, name: "rx", default: 0)
        }
        if FormReader.hasInput(optouter, "ry") {
            imageSizeHeight = FormReader.float(node: optouter, name: "ry", default: 0)
        }
        if FormReader.hasInput(optouter, "oi") {
            useOriginalImages = FormReader.int(node: optouter, name: "oi") == 1
        }
    }

    mutating func parseGalleryOptions(optouter: Kanna.XMLElement) {
        if FormReader.hasInput(optouter, "tl") {
            galleryName = FormReader.enumValue(node: optouter, name: "tl")
        }
        if FormReader.hasInput(optouter, "ar") {
            archiverBehavior = FormReader.enumValue(node: optouter, name: "ar")
        }
        if FormReader.hasInput(optouter, "dm") {
            displayMode = FormReader.enumValue(node: optouter, name: "dm")
        }
        if FormReader.hasInput(optouter, "pp") {
            showSearchRangeIndicator = FormReader.int(node: optouter, name: "pp") == 0
        }
        if FormReader.hasInput(optouter, "xn_0") {
            enableGalleryThumbnailSelector = FormReader.checkBoxBool(node: optouter, name: "xn_0")
        }
        if optouter.at_xpath("//div [@id='favsel']") != nil {
            favoriteCategories = Array(0...9).map { "favorite_\($0)" }
                .compactMap { FormReader.string(node: optouter, name: $0) }
        }
        if FormReader.hasInput(optouter, "fs") {
            favoritesSortOrder = FormReader.enumValue(node: optouter, name: "fs")
        }
        if FormReader.hasInput(optouter, "ru") {
            ratingsColor = FormReader.string(node: optouter, name: "ru") ?? ""
        }
        if FormReader.hasInput(optouter, "rc") {
            searchResultCount = FormReader.enumValue(node: optouter, name: "rc")
            capableSearchResultCount = FormReader.capability(node: optouter, name: "rc")
        }
        if FormReader.hasInput(optouter, "cs") {
            commentsSortOrder = FormReader.enumValue(node: optouter, name: "cs")
        }
        if FormReader.hasInput(optouter, "sc") {
            commentVotesShowTiming = FormReader.enumValue(node: optouter, name: "sc")
        }
        if FormReader.hasInput(optouter, "tb") {
            tagsSortOrder = FormReader.enumValue(node: optouter, name: "tb")
        }
        if FormReader.hasInput(optouter, "pn") {
            galleryPageNumbers = FormReader.enumValue(node: optouter, name: "pn")
        }
    }

    mutating func parseFilterOptions(optouter: Kanna.XMLElement) {
        if optouter.at_xpath("//div [@id='catsel']") != nil {
            disabledCategories = Array(0...9)
                .map { "ct_\(EhSetting.categoryNames[$0])" }
                .compactMap { FormReader.bool(node: optouter, name: $0) }
        }
        if FormReader.hasInput(optouter, "ft") {
            tagFilteringThreshold = FormReader.float(node: optouter, name: "ft", default: 0)
        }
        if FormReader.hasInput(optouter, "wt") {
            tagWatchingThreshold = FormReader.float(node: optouter, name: "wt", default: 0)
        }
        if FormReader.hasInput(optouter, "tf") {
            showFilteredRemovalCount = FormReader.int(node: optouter, name: "tf") == 0
        }
        if optouter.at_xpath("//div [@id='xlasel']") != nil {
            excludedLanguages = Array(0...49)
                .map { "xl_\(EhSetting.languageValues[$0])" }
                .compactMap { FormReader.checkBoxBool(node: optouter, name: $0) }
        }
        if optouter.at_xpath("//textarea [@name='xu']") != nil {
            excludedUploaders = optouter.at_xpath("//textarea [@name='xu']")?.text ?? ""
        }
    }

    mutating func parseThumbnailOptions(optouter: Kanna.XMLElement) {
        if FormReader.hasInput(optouter, "lt") {
            thumbnailLoadTiming = FormReader.enumValue(node: optouter, name: "lt")
        }
        if FormReader.hasInput(optouter, "ts") {
            parseThumbnailSizes(optouter: optouter)
        }
        if FormReader.hasInput(optouter, "tr") {
            thumbnailConfigRows = FormReader.enumValue(node: optouter, name: "tr")
            capableThumbnailConfigRowCount = FormReader.capability(node: optouter, name: "tr")
        }
        if FormReader.hasInput(optouter, "tp") {
            coverScaleFactor = FormReader.float(node: optouter, name: "tp", default: 100)
        }
        if FormReader.hasInput(optouter, "vp") {
            viewportVirtualWidth = FormReader.float(node: optouter, name: "vp", default: 0)
        }
    }

    private mutating func parseThumbnailSizes(optouter: Kanna.XMLElement) {
        var options = [(value: Int, isEnabled: Bool, isSelected: Bool)]()
        for link in optouter.xpath("//input [@name='ts']") {
            if let valueString = link["value"], let value = Int(valueString) {
                let isEnabled = link["disabled"] != "disabled"
                let isSelected = link["checked"] == "checked"
                options.append((value: value, isEnabled: isEnabled, isSelected: isSelected))
            }
        }
        // The form's values, not `ThumbnailSize` raw values.
        let thumbnailSize: (Int) -> EhSetting.ThumbnailSize? = {
            switch $0 {
            case 0: .auto
            case 1: .normal
            case 2: .small
            default: nil
            }
        }
        for option in options where option.isEnabled {
            if let size = thumbnailSize(option.value) {
                capableThumbnailConfigSizes.append(size)
            }
        }
        if let selectedSize = (options.first(where: \.isSelected)?.value).flatMap(thumbnailSize) {
            thumbnailConfigSize = selectedSize
        }
    }

    mutating func parseViewerOptions(optouter: Kanna.XMLElement) {
        if FormReader.hasInput(optouter, "qb") {
            useMultiplePageViewer = FormReader.int(node: optouter, name: "qb") == 1
        }
        if FormReader.hasInput(optouter, "ms") {
            multiplePageViewerStyle = FormReader.enumValue(node: optouter, name: "ms")
        }
        if FormReader.hasInput(optouter, "mt") {
            multiplePageViewerShowThumbnailPane = FormReader.int(node: optouter, name: "mt") == 0
        }
    }
}
