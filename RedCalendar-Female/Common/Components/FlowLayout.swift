//
//  FlowLayout.swift
//  RedCalendar-Female
//

import SwiftUI

// Data-driven flow layout. Compatible with iOS 15+ — uses alignmentGuide-based
// wrapping rather than the iOS 16 Layout protocol.
//
// **The per-element views are built in `init`, not in `body`, and that is what makes a chip
// answer a tap.** The content used to be stored as a closure and called from inside the
// `GeometryReader` — so the one thing that changed when a tag was selected (the `isFilled` the
// closure would have produced) was not visible anywhere in this view's own value. Every stored
// property compared equal, `body` was never re-run, and the tag picker's chips drew their
// original state for the life of the sheet however many times they were tapped. Building the
// views up front puts that difference back where SwiftUI looks for it. It costs nothing: the
// same views were being built on the same body pass, one call deeper.
struct FlowLayout<ItemID: Hashable, Content: View>: View {
    private struct Item: Identifiable {
        let id: ItemID
        let view: Content
    }

    private let items: [Item]
    private let spacing: CGFloat
    private let rowSpacing: CGFloat

    @State private var totalHeight: CGFloat = 0

    init<Data: RandomAccessCollection>(
        data: Data,
        id: KeyPath<Data.Element, ItemID>,
        spacing: CGFloat = 8,
        rowSpacing: CGFloat = 8,
        @ViewBuilder content: (Data.Element) -> Content
    ) {
        self.items = data.map { Item(id: $0[keyPath: id], view: content($0)) }
        self.spacing = spacing
        self.rowSpacing = rowSpacing
    }

    var body: some View {
        GeometryReader { geometry in
            self.generate(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generate(in geometry: GeometryProxy) -> some View {
        let cursor = FlowLayoutCursor()
        let lastID = items.last?.id
        let availableWidth = geometry.size.width

        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                let isLast = item.id == lastID

                item.view
                    .padding(.trailing, spacing)
                    .padding(.bottom, rowSpacing)
                    .alignmentGuide(.leading) { d in
                        if abs(cursor.x - d.width) > availableWidth {
                            cursor.x = 0
                            cursor.y -= d.height
                        }
                        let result = cursor.x
                        cursor.x = isLast ? 0 : cursor.x - d.width
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = cursor.y
                        if isLast {
                            cursor.y = 0
                        }
                        return result
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

private struct FlowLayoutHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// `alignmentGuide`'s closures accumulate a running offset across every child in the ZStack, so
// the cursor has to be shared reference state — a captured `var` cannot cross from one child's
// closure to the next. `@unchecked Sendable` is the honest annotation for it rather than a
// workaround: SwiftUI resolves one stack's alignment guides serially within a single layout
// pass, in the order `ForEach` presents its children, which is the ordering this cursor's
// left-to-right, top-to-bottom accumulation already depended on before either type had a name.
private final class FlowLayoutCursor: @unchecked Sendable {
    var x: CGFloat = 0
    var y: CGFloat = 0
}
