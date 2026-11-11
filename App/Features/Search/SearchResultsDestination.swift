import EhFeatures
import EhModels
import SwiftUI

/// `Route.typedSearch(keyword:)` and `Route.search(keyword:)`: search results for a keyword.
/// A search typed in the Search tab is added to the search history; a "detail search" built
/// from a tag, an uploader or a title is not.
struct SearchResultsDestination: View {
    let keyword: String
    var recordsHistory = false

    @State private var hasAppeared = false

    var body: some View {
        SearchResultsView(keyword: keyword, recordsHistory: recordsHistory)
            // Legacy played a soft haptic when a detail search was pushed.
            .sensoryFeedback(.impact(flexibility: .soft), trigger: hasAppeared) { _, appeared in
                appeared && !recordsHistory
            }
            .onAppear { hasAppeared = true }
    }
}
