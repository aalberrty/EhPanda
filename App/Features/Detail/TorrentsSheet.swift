import EhFeatures
import EhModels
import SwiftUI

/// The gallery's torrents. Tapping a file name copies its magnet link; swiping shares the file.
struct TorrentsSheet: View {
    @State private var model: TorrentsModel
    @State private var hud: HUDConfiguration?

    init(gid: String, token: String) {
        _model = State(initialValue: TorrentsModel(gid: gid, token: token))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.Localizable.TorrentsView.Title.torrents)
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .task { await model.load() }
        .hud($hud)
        .onChange(of: model.copyCount) { hud = .copiedToClipboard }
        .sensoryFeedback(.success, trigger: model.copyCount)
        .sensoryFeedback(.impact(weight: .light), trigger: model.sharedFile) { _, file in file != nil }
        .sheet(item: $model.sharedFile) { file in
            ActivityView(items: [file.url])
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.torrents.isEmpty {
            List(model.torrents) { torrent in
                TorrentRow(torrent: torrent) { model.copyMagnet(of: torrent) }
                    .swipeActions {
                        Button {
                            model.shareFile(of: torrent)
                        } label: {
                            Label(L10n.Localizable.DetailView.ToolbarItem.Button.share, systemImage: "arrow.down.doc.fill")
                        }
                        .tint(.accentColor)
                    }
            }
        } else if let error = model.loadingState.failed {
            ErrorStateView(error: error, retry: model.retry)
        } else {
            LoadingStateView()
        }
    }
}

private struct TorrentRow: View {
    let torrent: GalleryTorrent
    let copy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            HStack(spacing: Tokens.Spacing.medium) {
                figure(torrent.seedCount.formatted(), systemImage: "arrow.up.circle")
                figure(torrent.peerCount.formatted(), systemImage: "arrow.down.circle")
                figure(torrent.downloadCount.formatted(), systemImage: "checkmark.circle")
                Spacer(minLength: 0)
                figure(torrent.fileSize, systemImage: "doc.circle")
            }
            .font(.subheadline)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Button(action: copy) {
                Text(torrent.fileName)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
            }

            HStack {
                Spacer()
                Text(torrent.uploader)
                Text(torrent.formattedDateString)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .padding(.vertical, Tokens.Spacing.small)
    }

    private func figure(_ value: String, systemImage: String) -> some View {
        Label(value, systemImage: systemImage)
            .labelStyle(CompactLabelStyle())
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
