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
        let lastID = data.last?[keyPath: id]
        let availableWidth = geometry.size.width

        return ZStack(alignment: .topLeading) {
            ForEach(data, id: id) { item in
                let isLast = item[keyPath: id] == lastID

                content(item)
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
