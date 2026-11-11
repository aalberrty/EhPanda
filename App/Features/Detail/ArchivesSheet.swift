import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Hentai@Home archive options, the account's funds and the download command.
struct ArchivesSheet: View {
    @State private var model: ArchivesModel

    init(gallery: Gallery, archiveURL: URL) {
        _model = State(initialValue: ArchivesModel(gallery: gallery, archiveURL: archiveURL))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.Localizable.ArchivesView.Title.archives)
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .task { await model.load() }
        .hud(downloadHUD)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: model.selectionCount)
        .sensoryFeedback(trigger: model.feedback) { _, feedback in
            feedback.map { $0.isSuccess ? .success : .error }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.archives.isEmpty {
            VStack(spacing: Tokens.Spacing.medium) {
                ArchiveOptionsGrid(archives: model.archives, selection: model.selection, select: model.select)
                ArchiveFunds()
                Button(action: model.sendDownloadCommand) {
                    Text(L10n.Localizable.ArchivesView.Button.downloadToHathClient)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .disabled(model.selection == nil)
                .padding([.horizontal, .bottom])
            }
        } else if let error = model.loadingState.failed {
            ErrorStateView(message: error.alertText, systemImage: error.symbol.rawValue, retry: model.retry)
        } else {
            LoadingStateView()
        }
    }

    private var downloadHUD: Binding<HUDConfiguration?> {
        Binding(
            get: {
                switch model.download {
                case .communicating: .communicating
                case .finished(let result): Self.hud(for: result)
                case nil: nil
                }
            },
            set: { if $0 == nil { model.dismissDownloadResult() } }
        )
    }

    private static func hud(for result: ArchivesModel.DownloadResult) -> HUDConfiguration {
        switch result {
        case .success(let message): .success(caption: message)
        case .hathClientNotFound: .error(caption: L10n.Localizable.Website.Response.hathClientNotFound)
        case .hathClientNotOnline: .error(caption: L10n.Localizable.Website.Response.hathClientNotOnline)
        case .invalidResolution: .error(caption: L10n.Localizable.Website.Response.invalidResolution)
        case .failed: .error
        }
    }
}

private struct ArchiveOptionsGrid: View {
    let archives: [GalleryArchive.HathArchive]
    let selection: ArchiveResolution?
    let select: (GalleryArchive.HathArchive) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let width = Tokens.ImageSize.archiveGridWidth(for: sizeClass)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: width, maximum: width))], spacing: Tokens.Spacing.medium) {
                ForEach(archives) { archive in
                    Button {
                        select(archive)
                    } label: {
                        ArchiveOptionCell(archive: archive, isSelected: archive.resolution == selection, width: width)
                    }
                    .buttonStyle(.plain)
                    .disabled(!archive.isValid)
                }
            }
            .padding(.top, Tokens.Spacing.xLarge)
        }
    }
}

private struct ArchiveOptionCell: View {
    let archive: GalleryArchive.HathArchive
    let isSelected: Bool
    let width: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card / 2, style: .continuous)
        VStack(spacing: Tokens.Spacing.small) {
            Text(archive.resolution.localizedName)
                .font(.title3.bold())
            VStack(spacing: Tokens.Spacing.xxSmall) {
                Text(archive.fileSize)
                    .font(.caption.weight(.medium))
                Text(archive.price)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .foregroundStyle(archive.isValid ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
        .frame(width: width, height: width / 1.5)
        .contentShape(shape)
        .glassEffect(.regular.interactive(archive.isValid), in: shape)
        .overlay {
            shape.strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// GP and credits, read from the user store, which the archive page keeps current.
private struct ArchiveFunds: View {
    @Environment(UserStore.self) private var userStore

    var body: some View {
        if let galleryPoints = userStore.galleryPoints.flatMap({ Int($0) }),
           let credits = userStore.credits.flatMap({ Int($0) }) {
            HStack(spacing: Tokens.Spacing.xLarge) {
                Label(galleryPoints.formatted(), systemImage: "g.circle.fill")
                Label(credits.formatted(), systemImage: "c.circle.fill")
            }
            .font(.headline)
            .lineLimit(1)
            .contentTransition(.numericText())
            .animation(.default, value: galleryPoints)
            .animation(.default, value: credits)
        }
    }
}
