import EhModels
import Foundation
import Testing
@testable import EhParser

struct DocumentTests {
    @Test func parsesUTF8() throws {
        let doc = try Parser.htmlDocument(data: Data("<p id='x'>héllo</p>".utf8))
        #expect(doc.at_xpath("//p [@id='x']")?.text == "héllo")
    }

    @Test func invalidUTF8NeedsRecovery() throws {
        var data = Data("<p id='x'>ok ".utf8)
        data.append(contentsOf: [0xFF, 0xFE])
        data.append(contentsOf: Data(" end</p>".utf8))

        #expect(throws: AppError.parseFailed) { try Parser.htmlDocument(data: data) }
        let doc = try Parser.htmlDocument(data: data, recoversInvalidUTF8: true)
        #expect(doc.at_xpath("//p [@id='x']")?.text == "ok \u{FFFD}\u{FFFD} end")
    }

    @Test func rippingStopsAtNUL() {
        var data = Data("abc".utf8)
        data.append(0)
        data.append(contentsOf: Data("def".utf8))
        #expect(data.utf8InvalidCharactersRipped == Data("abc".utf8))
    }

    @Test func validURLDetection() {
        #expect("https://e-hentai.org/g/1/a/".isValidURL)
        #expect(!"None".isValidURL)
        #expect(!"see https://e-hentai.org/".isValidURL)
    }
}

struct TagTranslationDecodingTests {
    @Test func newerRelease() throws {
        let data = Data(#"{"tag_name":"v6","published_at":"2024-01-02T03:04:05Z"}"#.utf8)
        let date = try Parser.parseTagTranslatorReleaseDate(data: data, updatedDate: .distantPast)
        #expect(date == utcDate(2024, 1, 2, 3, 4, 5))
    }

    @Test func noNewerRelease() throws {
        let data = Data(#"{"published_at":"2024-01-02T03:04:05Z"}"#.utf8)
        #expect(throws: AppError.noUpdates) {
            try Parser.parseTagTranslatorReleaseDate(data: data, updatedDate: utcDate(2024, 1, 2, 3, 4, 5))
        }
    }

    @Test(arguments: [#"{"published_at":"yesterday"}"#, #"{}"#, "[]", "nope"])
    func unreadableRelease(json: String) {
        #expect(throws: AppError.parseFailed) {
            try Parser.parseTagTranslatorReleaseDate(data: Data(json.utf8), updatedDate: .distantPast)
        }
    }

    @Test func translations() throws {
        let data = Data("""
        {"data":[
          {"namespace":"female","data":{"big breasts":{"name":"巨乳","intro":"Large.","links":""}}},
          {"namespace":"notanamespace","data":{"x":{"name":"y"}}}
        ]}
        """.utf8)
        let translations = try Parser.parseTagTranslations(data: data)
        #expect(translations.count == 1)
        let translation = try #require(translations["femalebig breasts"])
        #expect(translation.namespace == .female)
        #expect(translation.key == "big breasts")
        #expect(translation.value == "巨乳")
    }

    @Test(arguments: [#"{"data":[]}"#, #"{"data":[{"namespace":"unknown","data":{}}]}"#, "{}", "nope"])
    func emptyOrBrokenTranslations(json: String) {
        #expect(throws: AppError.parseFailed) { try Parser.parseTagTranslations(data: Data(json.utf8)) }
    }
}
