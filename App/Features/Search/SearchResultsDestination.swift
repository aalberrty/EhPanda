import EhFeatures
import EhModels
import SwiftUI

/// `Route.typedSearch(keyword:)` and `Route.search(keyword:)`: search results for a keyword.
/// A search typed in the Search tab is added to the search history; a "detail search" built
/// from a tag, an uploader or a title is not.
struct SearchResultsDestination: View {
    let keyword: String
    var recordsHistory = false

    // The detail screen's buttons that push a detail search play its soft haptic.
    var body: some View {
        SearchResultsView(keyword: keyword, recordsHistory: recordsHistory)
    }
}
