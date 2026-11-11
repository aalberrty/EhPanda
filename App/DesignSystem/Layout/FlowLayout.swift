import SwiftUI

/// Wraps its subviews into lines, left to right, like words in a paragraph (replaces legacy
/// `TagCloudView`).
///
/// It measures once per layout pass from cached ideal sizes: no `GeometryReader`, no alignment
/// guide tricks and no height written back asynchronously. Items within a line are centred
/// vertically. A subview wider than the container is offered the container's width, so a chip
/// with `lineLimit(1)` truncates instead of overflowing.
///
/// With `maxLines`, subviews that do not fit are moved out of sight at zero size. They still
/// exist, so for exact VoiceOver output pass only the visible items when the count is known.
struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var maxLines: Int?

    init(spacing: CGFloat = Tokens.Spacing.xSmall, lineSpacing: CGFloat? = nil, maxLines: Int? = nil) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing ?? spacing
        self.maxLines = maxLines
    }

    struct Cache {
        var idealSizes: [CGSize]
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(idealSizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews, cache: cache).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let arrangement = arrange(maxWidth: bounds.width, subviews: subviews, cache: cache)
        for index in subviews.indices {
            if let frame = arrangement.frames[index] {
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(frame.size)
                )
            } else {
                // Every subview must be placed or SwiftUI centres it in the bounds.
                subviews[index].place(
                    at: CGPoint(x: bounds.minX - 10_000, y: bounds.minY),
                    anchor: .topLeading,
                    proposal: .zero
                )
            }
        }
    }

    private struct Arrangement {
        /// Frames relative to the layout's origin; `nil` for subviews past `maxLines`.
        var frames: [CGRect?]
        var size: CGSize
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews, cache: Cache) -> Arrangement {
        var frames = [CGRect?](repeating: nil, count: subviews.count)
        var line: [(index: Int, size: CGSize, x: CGFloat)] = []
        var lineCount = 0
        var cursorX: CGFloat = 0
        var lineY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        func commitLine() {
            for item in line {
                let y = lineY + (lineHeight - item.size.height) / 2
                frames[item.index] = CGRect(origin: CGPoint(x: item.x, y: y), size: item.size)
            }
            lineCount += 1
        }

        for index in subviews.indices {
            var size = cache.idealSizes[index]
            if size.width > maxWidth {
                size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                size.width = min(size.width, maxWidth)
            }
            if !line.isEmpty, cursorX + spacing + size.width > maxWidth {
                commitLine()
                line.removeAll(keepingCapacity: true)
                if let maxLines, lineCount >= maxLines { break }
                lineY += lineHeight + lineSpacing
                lineHeight = 0
            }
            let x = line.isEmpty ? 0 : cursorX + spacing
            line.append((index, size, x))
            cursorX = x + size.width
            lineHeight = max(lineHeight, size.height)
            usedWidth = max(usedWidth, cursorX)
        }
        if !line.isEmpty {
            commitLine()
        }
        let height = lineCount == 0 ? 0 : lineY + lineHeight
        return Arrangement(frames: frames, size: CGSize(width: usedWidth, height: height))
    }
}

private struct FlowLayoutPreview: View {
    private let words = [
        "language", "translated", "english", "female", "glasses", "very long tag that needs truncation",
        "sole male", "full color", "ponytail", "schoolgirl uniform", "story arc", "x",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xLarge) {
            FlowLayout {
                ForEach(words, id: \.self) { TagChip($0) }
            }
            FlowLayout(spacing: Tokens.Spacing.small, maxLines: 2) {
                ForEach(words, id: \.self) { TagChip($0, font: .caption) }
            }
            .border(.red.opacity(0.3))
        }
    }
}

#Preview {
    SchemePreview { FlowLayoutPreview() }
}
