import SwiftUI

// Placeholder owned by the Search feature, which replaces this file with the real field
// (tag suggestions included). Keep the signature.
extension View {
    /// A `.searchable` field that also suggests tags.
    func tagSearchable(text: Binding<String>, prompt: String, onSubmit: @escaping () -> Void) -> some View {
        searchable(text: text, prompt: prompt)
            .onSubmit(of: .search, onSubmit)
    }
}
