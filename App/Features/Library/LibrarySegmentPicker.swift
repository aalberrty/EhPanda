import EhFeatures
import SwiftUI

/// Favorites, Watched and History: the three-part control under the Library title.
struct LibrarySegmentPicker: View {
    let model: LibraryModel

    var body: some View {
        Picker(L10n.Localizable.TabItem.Title.library, selection: selection) {
            ForEach(LibrarySegment.allCases, id: \.self) { segment in
                Text(segment.localizedName).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .padding(.horizontal, Tokens.Spacing.large)
        .padding(.vertical, Tokens.Spacing.small)
    }

    private var selection: Binding<LibrarySegment> {
        Binding(get: { model.segment }, set: { model.select($0) })
    }
}

/// "All", then each favourites folder by the user's own name or "Favorites N" (replacing the
/// legacy folder menu). The selected chip scrolls into view.
struct FavoriteFolderChips: View {
    let model: FavoritesModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Tokens.Spacing.small) {
                    ForEach(model.folders) { folder in
                        FolderChip(title: title(of: folder), isSelected: folder.index == model.category) {
                            model.select(category: folder.index)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.large)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.category, initial: true) { old, category in
                guard category != old else {
                    // Appearing (after logging in, say): no animation.
                    proxy.scrollTo(category, anchor: .center)
                    return
                }
                withAnimation { proxy.scrollTo(category, anchor: .center) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Localizable.FavoritesView.Title.favorites)
    }

    private func title(of folder: FavoriteFolder) -> String {
        if folder.isAll { return L10n.Localizable.Struct.User.FavoriteCategory.all }
        return folder.customName ?? L10n.Localizable.Struct.User.FavoriteCategory.default("\(folder.index)")
    }
}

/// A folder chip: a filled capsule in a full-height touch target, inverted when selected.
///
/// The selected chip uses the UIKit label and background colours: on the iOS 18 bar material
/// `.primary` (the style and the colour) turns into a vibrant grey.
private struct FolderChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(.primary))
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .background(isSelected ? AnyShapeStyle(Color(.label)) : AnyShapeStyle(.fill.tertiary), in: .capsule)
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
