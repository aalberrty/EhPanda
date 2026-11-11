import EhFeatures
import EhModels
import SwiftUI

/// `Route.search(keyword:)`: a "detail search" built from a tag, an uploader or a title.
/// Unlike a search typed in the Search tab, it does not add to the search history.
struct SearchResultsDestination: View {
    let keyword: String

    @State private var hasAppeared = false

    var body: some View {
        SearchResultsView(keyword: keyword, recordsHistory: false)
            // Legacy played a soft haptic when a detail search was pushed.
            .sensoryFeedback(.impact(flexibility: .soft), trigger: hasAppeared) { _, appeared in appeared }
            .onAppear { hasAppeared = true }
    }
}
