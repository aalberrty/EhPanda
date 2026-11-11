import EhTestSupport
import Foundation

/// Rows for legacy stores, in the shapes the last legacy release wrote.
enum LegacyFixtures {
    static let tagsJSON = """
    [{ "rawNamespace": "female", "contents": [
        { "rawNamespace": "female", "text": "glasses", "isVotedUp": true, "isVotedDown": false,
          "textColor": { "red": 1, "green": 1, "blue": 1 }, "backgroundColor": { "red": 1, "green": 0, "blue": 0 } }
    ] }]
    """
    static let quickSearchWordID = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    static let quickSearchWordsJSON = #"[{ "id": "\#(quickSearchWordID)", "name": "Mine", "content": "f:glasses$" }]"#
    static let historyKeywordsJSON = #"["oldest", "middle", "newest"]"#

    static func blob(_ text: String) -> LegacyStoreBuilder.Value {
        .blob(Data(text.utf8))
    }

    static func insertAppEnv(_ builder: LegacyStoreBuilder, blobs: Bool = true) throws {
        func value(_ text: String) -> LegacyStoreBuilder.Value { blobs ? blob(text) : .null }
        try builder.insert(into: "ZAPPENVMO", [
            "ZUSER": value(#"{"displayName":"panda"}"#),
            "ZSETTING": value(#"{"galleryHost":"ExHentai"}"#),
            "ZSEARCHFILTER": value(#"{"search":1}"#),
            "ZGLOBALFILTER": value(#"{"global":1}"#),
            "ZWATCHEDFILTER": value(#"{"watched":1}"#),
            "ZTAGTRANSLATOR": value(#"{"translations":{}}"#),
            "ZHISTORYKEYWORDS": value(historyKeywordsJSON),
            "ZQUICKSEARCHWORDS": value(quickSearchWordsJSON)
        ])
    }

    static func insertGallery(
        _ builder: LegacyStoreBuilder, gid: String, lastOpenDate: LegacyStoreBuilder.Value,
        tags: LegacyStoreBuilder.Value = blob(tagsJSON)
    ) throws {
        try builder.insert(into: "ZGALLERYMO", [
            "ZGID": .text(gid), "ZTOKEN": .text("tok\(gid)"), "ZTITLE": .text("Title \(gid)"),
            "ZRATING": .double(4.5), "ZCATEGORY": .text("Manga"), "ZUPLOADER": .text("uploader"),
            "ZPAGECOUNT": .int(30), "ZPOSTEDDATE": .int(700_000_000),
            "ZCOVERURL": .text("https://ehgt.org/\(gid).jpg"),
            "ZGALLERYURL": .text("https://e-hentai.org/g/\(gid)/tok\(gid)/"),
            "ZTAGS": tags, "ZLASTOPENDATE": lastOpenDate
        ])
    }

    static func insertState(_ builder: LegacyStoreBuilder, gid: String, progress: Int) throws {
        try builder.insert(into: "ZGALLERYSTATEMO", [
            "ZGID": .text(gid), "ZREADINGPROGRESS": .int(progress),
            "ZPREVIEWCONFIG": blob(#"{"large":{"rows":4}}"#),
            "ZIMAGEURLS": blob(#"{"1":"https://x.org/1.jpg"}"#),
            "ZCOMMENTS": .null, "ZTAGS": .null, "ZTHUMBNAILURLS": .null,
            "ZORIGINALIMAGEURLS": .null, "ZPREVIEWURLS": .null
        ])
    }

    static func insertDetail(_ builder: LegacyStoreBuilder, gid: String) throws {
        try builder.insert(into: "ZGALLERYDETAILMO", [
            "ZGID": .text(gid), "ZTITLE": .text("Title"), "ZCATEGORY": .text("Manga"),
            "ZLANGUAGE": .text("Japanese"), "ZVISIBILITY": blob(#"{"yes":{}}"#),
            "ZPOSTEDDATE": .double(700_000_000.5)
        ])
    }

    /// A store like a long-time user's: settings, three opened galleries (one stored twice),
    /// many list-only galleries, state and detail rows.
    static func populateComplete(_ builder: LegacyStoreBuilder) throws {
        try insertAppEnv(builder)
        try insertGallery(builder, gid: "100", lastOpenDate: .int(700_000_100))
        try insertGallery(builder, gid: "200", lastOpenDate: .double(700_000_300.25))
        try insertGallery(builder, gid: "300", lastOpenDate: .int(700_000_200))
        try insertGallery(builder, gid: "100", lastOpenDate: .int(600_000_000))
        for gid in 1_000..<1_050 {
            try insertGallery(builder, gid: "\(gid)", lastOpenDate: .null)
        }
        try insertState(builder, gid: "100", progress: 12)
        try insertState(builder, gid: "1000", progress: 3)
        try insertDetail(builder, gid: "100")
    }
}
