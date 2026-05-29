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
        var x: CGFloat = 0
        var y: CGFloat = 0
        let lastID = data.last?[keyPath: id]

        return ZStack(alignment: .topLeading) {
            ForEach(data, id: id) { item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, rowSpacing)
                    .alignmentGuide(.leading) { d in
                        if abs(x - d.width) > geometry.size.width {
                            x = 0
                            y -= d.height
                        }
                        let result = x
                        if item[keyPath: id] == lastID {
                            x = 0
                        } else {
                            x -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = y
                        if item[keyPath: id] == lastID {
                            y = 0
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
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
