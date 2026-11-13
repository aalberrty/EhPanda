import Foundation
import SwiftUI

/// Settings › About EhPanda (legacy `AboutView`): contacts, credits and acknowledgements.
/// Links open outside the app.
struct AboutScreen: View {
    var body: some View {
        Form {
            Group {
                Section {
                    AboutLinkRows(links: AboutLink.contacts)
                } header: {
                    // iOS 18 has no large-title subtitle, so the credits head the first section.
                    if #unavailable(iOS 26) {
                        credits.textCase(nil)
                    }
                }
                Section(L10n.Localizable.AboutView.Section.Title.specialThanks) {
                    AboutLinkRows(links: AboutLink.specialThanks)
                }
                Section(L10n.Localizable.AboutView.Section.Title.codeLevelContributors) {
                    AboutLinkRows(links: AboutLink.codeLevelContributors)
                }
                Section(L10n.Localizable.AboutView.Section.Title.translationContributors) {
                    AboutLinkRows(links: AboutLink.translationContributors)
                }
                Section(L10n.Localizable.AboutView.Section.Title.acknowledgements) {
                    AboutLinkRows(links: AboutLink.acknowledgements)
                }
            }
            .raisedRows()
        }
        .screenGround(.grouped)
        .navigationTitle(L10n.Localizable.AboutView.Title.ehPanda)
        .toolbar {
            if #available(iOS 26, *) {
                ToolbarItem(placement: .largeSubtitle) {
                    credits
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Tokens.Spacing.xSmall)
                }
            }
        }
    }

    private var credits: some View {
        VStack(alignment: .leading) {
            Text(L10n.Constant.App.copyright)
            Text(Self.version)
        }
        .font(.caption2.bold())
        .foregroundStyle(.textSecondary)
        .accessibilityElement(children: .combine)
    }

    /// "Version 3.0.0 (42)".
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return [L10n.Localizable.AboutView.Title.version, version, "(\(build))"].joined(separator: " ")
    }
}

private struct AboutLinkRows: View {
    let links: [AboutLink]

    var body: some View {
        ForEach(links) { link in
            if let url = link.url {
                Link(destination: url) {
                    HStack {
                        Text(link.text).fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .foregroundStyle(.textPrimary)
            } else {
                // Credits without a profile link are listed as plain text, as in legacy.
                Text(link.text).fontWeight(.medium).foregroundStyle(.textPrimary)
            }
        }
    }
}

#Preview {
    NavigationStack { AboutScreen() }
}
