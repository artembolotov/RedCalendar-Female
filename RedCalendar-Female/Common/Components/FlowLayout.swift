//
//  FlowLayout.swift
//  RedCalendar-Female
//

import SwiftUI

// Data-driven flow layout. Compatible with iOS 15+ — uses alignmentGuide-based
// wrapping rather than the iOS 16 Layout protocol.
struct FlowLayout<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    let data: Data
    let id: KeyPath<Data.Element, ID>
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8
    @ViewBuilder let content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            self.generate(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generate(in geometry: GeometryProxy) -> some View {
        let cursor = FlowLayoutCursor()
        let rowWidth = geometry.size.width
        let id = self.id
        let lastID = data.last?[keyPath: id]

        return ZStack(alignment: .topLeading) {
            ForEach(data, id: id) { item in
                // Resolved here rather than inside the guides, which is what keeps `item`,
                // `lastID` and the view's own generic parameters out of those closures.
                let isLast = item[keyPath: id] == lastID

                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, rowSpacing)
                    .alignmentGuide(.leading) { d in
                        cursor.leading(
                            rowWidth: rowWidth,
                            itemWidth: d.width,
                            itemHeight: d.height,
                            isLast: isLast
                        )
                    }
                    .alignmentGuide(.top) { _ in
                        cursor.top(isLast: isLast)
                    }
            }
        }
        .background(heightReader)
    }

    private var heightReader: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: FlowLayoutHeightKey.self, value: geo.size.height)
        }
        .onPreferenceChange(FlowLayoutHeightKey.self) { value in
            totalHeight = value
        }
    }
}

/// Where the next item goes, carried across the alignment guides of one layout pass.
///
/// The wrapping arithmetic has to accumulate: each guide reads where the previous item left off
/// and writes where this one ends. In an `alignmentGuide` closure that used to be two `var`s
/// captured from `generate(in:)` — which is a mutable capture in a closure SwiftUI now declares
/// `@Sendable`, and the compiler rejects it. A box makes the sharing explicit instead of implicit.
///
/// `@unchecked` because the guarantee is SwiftUI's rather than the type's: guides are evaluated
/// during layout, on the main thread, one at a time. A cursor is also created per `generate(in:)`
/// call and captured by nothing else, so it never outlives the pass it belongs to.
private final class FlowLayoutCursor: @unchecked Sendable {
    private var x: CGFloat = 0
    private var y: CGFloat = 0

    func leading(rowWidth: CGFloat, itemWidth: CGFloat, itemHeight: CGFloat, isLast: Bool) -> CGFloat {
        if abs(x - itemWidth) > rowWidth {
            x = 0
            y -= itemHeight
        }
        let result = x
        x = isLast ? 0 : x - itemWidth
        return result
    }

    func top(isLast: Bool) -> CGFloat {
        let result = y
        if isLast { y = 0 }
        return result
    }
}

nonisolated private struct FlowLayoutHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
