import Foundation

/// One row of the About screen. URLs and names come from `Constant.strings`.
struct AboutLink: Identifiable {
    let text: String
    let url: URL?

    var id: String { text }

    init(_ urlString: String, _ text: String) {
        self.text = text
        url = urlString.isEmpty ? nil : URL(string: urlString)
    }
}

extension AboutLink {
    private typealias App = L10n.Constant.App

    static let contacts: [AboutLink] = [
        AboutLink(App.Contact.Link.website, L10n.Localizable.AboutView.Button.website),
        AboutLink(App.Contact.Link.gitHub, App.Contact.Text.gitHub),
        AboutLink(App.Contact.Link.discord, App.Contact.Text.discord),
        AboutLink(App.Contact.Link.telegram, App.Contact.Text.telegram),
        AboutLink(App.Contact.Link.altStore, L10n.Localizable.AboutView.Button.altStoreSource)
    ]

    static let specialThanks: [AboutLink] = [
        AboutLink(App.SpecialThanks.Link.taylorlannister, App.SpecialThanks.Text.taylorlannister),
        AboutLink(App.SpecialThanks.Link.luminescentYq, App.SpecialThanks.Text.luminescentYq),
        AboutLink(App.SpecialThanks.Link.caxerx, App.SpecialThanks.Text.caxerx),
        AboutLink(App.SpecialThanks.Link.honjow, App.SpecialThanks.Text.honjow)
    ]

    static let codeLevelContributors: [AboutLink] = [
        AboutLink(App.CodeLevelContributor.Link.chihchy, App.CodeLevelContributor.Text.chihchy),
        AboutLink(App.CodeLevelContributor.Link.aalberrty, App.CodeLevelContributor.Text.aalberrty),
        AboutLink(App.CodeLevelContributor.Link.jimmyPrime, App.CodeLevelContributor.Text.jimmyPrime),
        AboutLink(App.CodeLevelContributor.Link.xioxin, App.CodeLevelContributor.Text.xioxin),
        AboutLink(App.CodeLevelContributor.Link.vvbbnn00, App.CodeLevelContributor.Text.vvbbnn00)
    ]

    static let translationContributors: [AboutLink] = [
        AboutLink(App.TranslationContributor.Link.nebulosaCat, App.TranslationContributor.Text.nebulosaCat),
        AboutLink(App.TranslationContributor.Link.paulHaeussler, App.TranslationContributor.Text.paulHaeussler),
        AboutLink(App.TranslationContributor.Link.caxerx, App.TranslationContributor.Text.caxerx),
        AboutLink(App.TranslationContributor.Link.neKoOuO, App.TranslationContributor.Text.neKoOuO)
    ]

    /// The libraries v2 actually uses that have strings in `Constant.strings`. Legacy-only
    /// libraries (TCA, SwiftyBeaver, AlertKit, …) are gone; GRDB and swift-dependencies have
    /// no strings yet.
    static let acknowledgements: [AboutLink] = [
        AboutLink(App.Acknowledgement.Link.kanna, App.Acknowledgement.Text.kanna),
        AboutLink(App.Acknowledgement.Link.kingfisher, App.Acknowledgement.Text.kingfisher),
        AboutLink(App.Acknowledgement.Link.swiftGen, App.Acknowledgement.Text.swiftGen),
        AboutLink(App.Acknowledgement.Link.sfSafeSymbols, App.Acknowledgement.Text.sfSafeSymbols),
        AboutLink(App.Acknowledgement.Link.swiftyOpenCC, App.Acknowledgement.Text.swiftyOpenCC),
        AboutLink(
            App.Acknowledgement.Link.ehTagTranslationDatabase, App.Acknowledgement.Text.ehTagTranslationDatabase
        )
    ]
}
