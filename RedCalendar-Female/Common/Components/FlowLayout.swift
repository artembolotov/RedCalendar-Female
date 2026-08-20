//
//  FlowLayout.swift
//  RedCalendar-Female
//

import SwiftUI

// Data-driven flow layout. Compatible with iOS 15+ — uses alignmentGuide-based
// wrapping rather than the iOS 16 Layout protocol.
//
// **Nothing on the path from a changed input to a redrawn chip is a closure, and that is the
// whole design of this file.** Two things here used to be, and each of them swallowed a tag
// selection whole:
//
// The per-element content was stored as a closure and called during layout, so the one thing
// that differed when a tag was picked — the `isFilled` that closure would have produced — was
// invisible in this view's own value. `data` compared equal, the closure compared equal, and
// `body` was never re-run. The item views are built in `init` now and stored, the way SwiftUI's
// own containers store the content they are handed.
//
// And the content itself was returned from inside a `GeometryReader`, whose one stored property
// is *also* a closure: rebuilding it produced a value indistinguishable from the last one, so
// the chips inside it stayed as they were. That is why the picker used to come alive the moment
// anything was typed into its search field — filtering changes how many rows there are, the
// height changes with it, and a `GeometryReader` does re-read its content when the geometry
// under it moves. Selecting a tag changes no size at all. The width is read from a background
// preference into `@State` instead, and the wrapped stack is built in `body` where an ordinary
// rebuild reaches it.
//
// Losing the reader took the height feedback loop with it: the `ZStack` sizes itself to the
// union of its guide-shifted children, which is the number the old `.frame(height:)` was being
// fed anyway.
struct FlowLayout<ItemID: Hashable, Content: View>: View {
    private struct Item: Identifiable {
        let id: ItemID
        let view: Content
    }

    private let items: [Item]
    private let spacing: CGFloat
    private let rowSpacing: CGFloat

    @State private var availableWidth: CGFloat = 0

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
        Group {
            if availableWidth > 0 {
                wrapped(in: availableWidth)
            } else {
                // A stand-in rather than nothing at all: the width has to be measured off
                // something that fills the offered width, and this is the same zero height the
                // layout used to have on its first pass while it waited for its own reader.
                Color.clear.frame(height: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(widthReader)
    }

    private func wrapped(in availableWidth: CGFloat) -> some View {
        let cursor = FlowLayoutCursor()
        let lastID = items.last?.id

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
    }

    // The one `GeometryReader` left, and it is behind the content rather than around it: what
    // it measures is the offered width, which does not depend on anything the items draw, so
    // there is no loop and nothing downstream of it to go stale.
    private var widthReader: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: FlowLayoutWidthKey.self, value: geo.size.width)
        }
        .onPreferenceChange(FlowLayoutWidthKey.self) { value in
            availableWidth = value
        }
    }
}

private struct FlowLayoutWidthKey: PreferenceKey {
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
