//
//  CalendarHeaderView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI

// The weekday labels on a track, and nothing else. The strip no longer draws a divider under
// itself: it now sits on `CalendarTopChrome`'s blurred band, and the band's dissolving lower
// edge is the boundary. A hairline over a blur reads as window chrome — exactly the flat plate
// the band exists to get rid of.
//
// The track is the same shape as the period bar — `periodBarHeight`, `periodBarCornerRadius`,
// `.continuous` — in a neutral fill instead of the accent, so the row of labels reads as one
// object rather than seven loose words. It is the App Store Connect segmented control's
// concept without its mechanics: a container, no selection, no dividers, and the labels stay
// where the day columns are rather than being spaced by the container.
//
// Its width is the seven columns exactly, not the view: `ViewportCalculator` places day cells
// off the same `horizontalPadding`, so the track starts where Monday's column starts and ends
// where Sunday's ends. Anything wider and the bar would overhang the calendar it labels.
//
// A translucent fill rather than an opaque one, for the same reason the band is a blur and not
// a material: over the empty page a solid neutral is a grey plate, while a translucent one
// keeps whatever passes under the band visible through it.
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
            RoundedRectangle(
                cornerRadius: CalendarConstants.periodBarCornerRadius,
                style: .continuous
            )
            .fill(Color("WeekdaysBarColor"))
            .frame(width: width - horizontalPadding, height: CalendarConstants.periodBarHeight)
            .position(x: width / 2, y: height / 2)

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
