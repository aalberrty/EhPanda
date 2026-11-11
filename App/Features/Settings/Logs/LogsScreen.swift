import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Settings › General › Logs (legacy `LogsView`).
struct LogsScreen: View {
    @State private var model = LogsModel()

    var body: some View {
        content
            .navigationTitle(L10n.Localizable.LogsView.Title.logs)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.openLogsFolder() }
                    } label: {
                        Label(L10n.Localizable.LogsView.Title.logs, systemImage: "folder.badge.gearshape")
                    }
                }
            }
            .navigationDestination(item: $model.selectedLog) { file in
                LogDetailScreen(file: file)
            }
            .task { await model.load() }
            .refreshable { await model.load() }
    }

    @ViewBuilder private var content: some View {
        if model.logs.isEmpty {
            if model.loadingState.isLoading {
                LoadingStateView()
            } else {
                EmptyStateView()
            }
        } else {
            List {
                ForEach(model.logs) { log in
                    Button {
                        model.selectedLog = log.file
                    } label: {
                        LogRow(log: log, isLatest: log.file == model.latestLog)
                    }
                    .foregroundStyle(.primary)
                    .contextMenu {
                        ShareLink(item: log.file.url)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await model.delete(log) }
                        } label: {
                            Label(L10n.Localizable.ConfirmationDialog.Button.delete, systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

private struct LogRow: View {
    let log: LogSummary
    let isLatest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
            HStack {
                Text(log.file.name).font(.callout)
                Spacer()
                if isLatest {
                    Label(L10n.Localizable.LogsView.Title.latest, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.multicolor)
                }
            }
            HStack {
                Text(dateRange).bold()
                Spacer()
                Text(L10n.Localizable.Common.Value.records("\(log.recordCount)"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, Tokens.Spacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    private var dateRange: String {
        "\(log.firstDate ?? "") - \(log.lastDate ?? "")"
    }
}

#Preview {
    SettingsPreview { LogsScreen() }
}
