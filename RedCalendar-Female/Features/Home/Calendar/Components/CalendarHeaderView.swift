//
//  CalendarHeaderView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI

// The weekday labels and nothing else. The strip no longer draws a divider under itself:
// it now sits on `CalendarTopChrome`'s blurred band, and the band's dissolving lower edge
// is the boundary. A hairline over a blur reads as window chrome — exactly the flat plate
// the band exists to get rid of.
//
// Columns are positioned the same way `ViewportCalculator` places day cells, off the same
// `horizontalPadding`, so a label always stands over its own column.
struct CalendarHeaderView: View {
    let weekdays: [String]
    var weekendIndices: Set<Int> = []
    let width: CGFloat
    let height: CGFloat

    // MARK: - Constants
    private let horizontalPadding: CGFloat = CalendarConstants.horizontalPadding
    private let weekendOpacity: Double = 0.55

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { dayIndex, weekday in
                let dayWidth = (width - horizontalPadding) / 7
                let dayX = horizontalPadding / 2 + CGFloat(dayIndex) * dayWidth
                let centerX = dayX + dayWidth / 2

                Text(weekday)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.secondary)
                    .opacity(weekendIndices.contains(dayIndex) ? weekendOpacity : 1)
                    .position(x: centerX, y: height / 2)
            }
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    CalendarHeaderView(
        weekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"],
        weekendIndices: [5, 6],
        width: 375,
        height: CalendarConstants.weekdaysHeaderHeight
    )
}
