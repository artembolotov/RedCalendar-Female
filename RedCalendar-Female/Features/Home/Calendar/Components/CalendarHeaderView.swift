//
//  CalendarHeaderView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI

struct CalendarHeaderView: View {
    let weekdays: [String]
    var weekendIndices: Set<Int> = []
    let width: CGFloat
    let height: CGFloat

    // MARK: - Constants
    private let horizontalPadding: CGFloat = CalendarConstants.horizontalPadding
    private let dividerHeight: CGFloat = 1
    private let weekendOpacity: Double = 0.55
    private let dividerOpacity: Double = 0.5
    
    // Calculated properties
    private var weekdayContainerHeight: CGFloat {
        height - dividerHeight
    }
    
    private var textVerticalCenter: CGFloat {
        weekdayContainerHeight / 2
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                        .position(x: centerX, y: textVerticalCenter)
                }
            }
            .frame(width: width, height: weekdayContainerHeight)

            // Inset to the day columns rather than run edge to edge, and softened: a full-bleed
            // hairline reads as a window chrome divider and cuts the calendar in two.
            Divider()
                .frame(height: dividerHeight)
                .padding(.horizontal, horizontalPadding / 2)
                .opacity(dividerOpacity)
        }
        .frame(height: height)
    }
}

#Preview {
    CalendarHeaderView(
        weekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"],
        weekendIndices: [5, 6],
        width: 375,
        height: 60
    )
}
