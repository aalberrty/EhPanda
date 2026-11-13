import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The search filter as chips on one glass bar above the search field (E-Search): Filters with
/// the number of active filters, which opens the sheet, then the minimum rating and the ten
/// categories, which change the stored search filter in place.
struct SearchFilterBar: View {
    let showFilters: () -> Void

    @State private var model = SearchFilterBarModel()
    @State private var toggles = 0

    var body: some View {
        HStack(spacing: 6) {
            FiltersCountButton(count: model.activeFilterCount, action: showFilters)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    MinimumRatingChip(model: model)
                    ForEach(model.categories) { chip in
                        CategoryFilterChip(chip: chip) {
                            toggles += 1
                            model.toggle(chip.category)
                        }
                    }
                }
                .padding(.trailing, Tokens.Spacing.large)
            }
            .scrollIndicators(.hidden)
            .mask {
                // Chips running under the bar's end fade out instead of being cut.
                LinearGradient(stops: [.init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                               startPoint: .leading, endPoint: .trailing)
            }
        }
        .padding(.horizontal, Tokens.Spacing.xSmall)
        .frame(height: 52)
        .glassSurface(in: .capsule, tone: .bar)
        // Lines up with the iOS 26 bottom search row (its Home button and field) and sits about
        // 10 pt above it, as drawn.
        .padding(.horizontal, 28)
        .padding(.bottom, Tokens.Spacing.xSmall)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: toggles)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Localizable.FiltersView.Title.filters)
    }
}

/// The filter symbol and, when filters are on, their number on a bone (ink) badge.
private struct FiltersCountButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.body.weight(.medium))
                if count > 0 {
                    Text(count, format: .number)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.onSelectedFill)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(.selectedFill, in: .capsule)
                }
            }
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, 10)
            .frame(minWidth: 44, minHeight: 44)
            .background(.chipFill, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            count > 0
                ? L10n.Localizable.SearchView.FilterBar.filtersActive(count)
                : L10n.Localizable.ToolbarItem.Button.filters
        )
    }
}

/// The minimum rating: a menu with the sheet's switch and the four ratings. Drawn selected
/// (bone on the dark bar, ink on the light one) while a rating applies.
private struct MinimumRatingChip: View {
    let model: SearchFilterBarModel

    var body: some View {
        let rating = model.minimumRating
        Menu {
            Toggle(
                L10n.Localizable.FiltersView.Title.setMinimumRating,
                isOn: Binding(get: { rating != nil }, set: { model.setMinimumRatingOn($0) })
            )
            Picker(L10n.Localizable.FiltersView.Title.minimumRating, selection: selection(rating)) {
                ForEach(SearchFilterBarModel.ratings, id: \.self) { number in
                    Text(L10n.Localizable.Common.Value.stars("\(number)")).tag(Int?.some(number))
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: Tokens.Spacing.xSmall) {
                Image(systemName: rating == nil ? "star" : "star.fill")
                    .imageScale(.small)
                if let rating {
                    Text(L10n.Localizable.SearchView.FilterBar.minimumRating(rating))
                }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(rating == nil ? Color.textPrimary : .onSelectedFill)
            .modifier(FilterChipShape(isSelected: rating != nil, isFilled: false))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Localizable.FiltersView.Title.minimumRating)
        .accessibilityValue(rating.map { L10n.Localizable.Common.Value.stars("\($0)") } ?? "")
    }

    private func selection(_ rating: Int?) -> Binding<Int?> {
        Binding(get: { rating }, set: { model.setMinimumRating($0) })
    }
}

/// A category: its colour dot and name when results include it; when they leave it out, a
/// ring, a struck-through name in the tertiary colour and no fill. Tapping switches it.
private struct CategoryFilterChip: View {
    let chip: SearchCategoryChip
    let toggle: () -> Void

    @Environment(SettingsStore.self) private var settings
    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 8

    var body: some View {
        let category = chip.category
        let color = category.color(for: settings.galleryHost)
        Button(action: toggle) {
            HStack(spacing: 6) {
                dot(color)
                Text(category.localizedName)
                    .strikethrough(!chip.isIncluded)
                    .lineLimit(1)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(chip.isIncluded ? Color.textPrimary : .textTertiary)
            .modifier(FilterChipShape(isSelected: false, isFilled: chip.isIncluded))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.localizedName)
        .accessibilityAddTraits(chip.isIncluded ? .isSelected : [])
    }

    /// The vivid (light appearance) category colour, as `CategoryLabel` draws it.
    @ViewBuilder
    private func dot(_ color: Color) -> some View {
        Group {
            if chip.isIncluded {
                Circle()
                    .fill(color)
                    .overlay { Circle().strokeBorder(DesignColors.categoryRing, lineWidth: 1) }
            } else {
                Circle().strokeBorder(color, lineWidth: 1.5)
            }
        }
        .environment(\.colorScheme, .light)
        .frame(width: dotSize, height: dotSize)
    }
}

/// A 32 pt capsule inside a 44 pt tap target: selected (bone or ink fill), filled (the chip
/// fill) or outlined.
private struct FilterChipShape: ViewModifier {
    var isSelected: Bool
    var isFilled = true

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background {
                if isSelected {
                    Capsule().fill(.selectedFill)
                } else if isFilled {
                    Capsule().fill(.chipFill)
                } else {
                    Capsule().strokeBorder(.hairline, lineWidth: 1)
                }
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
    }
}

#Preview {
    SchemePreview {
        SearchFilterBar {}
            .padding(.vertical)
            .background(.ground)
    }
    .environment(SettingsStore(defaults: .standard))
}
