//
//  CalendarModels.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.08.2025.
//

import Foundation

struct ViewportData {
    let visibleMonths: [VisibleMonth]
}

struct VisibleMonth {
    let monthOffset: Int
    let yPosition: CGFloat
    let height: CGFloat
    let visibleDays: [VisibleDay]
}

struct VisibleDay {
    let date: Date?
    let isToday: Bool
    let xPosition: CGFloat
    let yPosition: CGFloat
    let dayNumber: String
}
