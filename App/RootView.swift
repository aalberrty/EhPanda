import SwiftUI

/// Temporary shell. Replaced by the real tab structure once the feature views land.
struct RootView: View {
    var body: some View {
        TabView {
            Tab(L10n.Localizable.TabItem.Title.home, systemImage: "house") {
                placeholder
            }
            Tab(L10n.Localizable.TabItem.Title.favorites, systemImage: "heart") {
                placeholder
            }
            Tab(L10n.Localizable.TabItem.Title.search, systemImage: "magnifyingglass", role: .search) {
                placeholder
            }
            Tab(L10n.Localizable.TabItem.Title.setting, systemImage: "gearshape") {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ContentUnavailableView {
            Label("EhPanda", systemImage: "hammer")
        } description: {
            Text(verbatim: "v2")
        } actions: {
            #if DEBUG
            ReaderHarnessLauncher()
            #endif
        }
    }
}

#Preview {
    RootView()
}
