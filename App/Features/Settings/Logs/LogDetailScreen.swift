import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The lines of one log file, numbered (legacy `LogView`), with the file shareable.
struct LogDetailScreen: View {
    @State private var model: LogDetailModel

    init(file: LogFile) {
        _model = State(initialValue: LogDetailModel(file: file))
    }

    var body: some View {
        content
            .navigationTitle(model.file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: model.file.url)
                }
            }
            .task { await model.load() }
    }

    @ViewBuilder private var content: some View {
        if let error = model.loadingState.failed {
            ErrorStateView(error: error) {
                Task { await model.load() }
            }
        } else if model.lines.isEmpty {
            if model.loadingState.isLoading {
                LoadingStateView()
            } else {
                EmptyStateView()
            }
        } else {
            List(model.lines.indices, id: \.self) { index in
                Text(verbatim: "\(index + 1). \(model.lines[index])")
                    .font(.caption.weight(.medium))
                    .textSelection(.enabled)
                    .padding(.vertical, Tokens.Spacing.xSmall)
            }
        }
    }
}
