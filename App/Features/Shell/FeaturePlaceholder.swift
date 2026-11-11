import SwiftUI

/// Stand-in for a feature screen that has not been built yet. Delete once nothing uses it.
struct FeaturePlaceholder: View {
    let name: String

    var body: some View {
        ContentUnavailableView(name, systemImage: "hammer", description: Text(verbatim: "Not built yet"))
            .navigationTitle(name)
    }
}
