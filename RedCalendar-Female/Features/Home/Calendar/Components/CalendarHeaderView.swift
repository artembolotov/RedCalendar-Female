//
//  CalendarHeaderView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI

struct CalendarHeaderView: View {
    let weekdays: [String]
    let width: CGFloat
    let height: CGFloat
    
    // MARK: - Constants
    private let horizontalPadding: CGFloat = CalendarConstants.horizontalPadding
    private let dividerHeight: CGFloat = 1
    
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
                        .position(x: centerX, y: textVerticalCenter)
                }
            }
            .frame(width: width, height: weekdayContainerHeight)
            
            Divider()
                .frame(height: dividerHeight)
        }
        .frame(height: height)
    }
}

#Preview {
    CalendarHeaderView(
        weekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"],
        width: 375,
        height: 60
    )
}
