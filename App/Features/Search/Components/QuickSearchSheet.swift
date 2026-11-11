import SwiftUI

// Placeholder owned by the Search feature, which replaces this file with the real sheet.
// Keep the initializer.
struct QuickSearchSheet: View {
    private let onSelect: (String) -> Void

    init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }

    var body: some View {
        EmptyView()
    }
}
