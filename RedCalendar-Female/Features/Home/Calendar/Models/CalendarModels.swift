//
//  CalendarModels.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.08.2025.
//

import Foundation

// Equatable throughout: the rendered grid compares its inputs to decide whether a scroll
// frame has to rebuild any day cells at all. Arrays hit the identity fast path, so an
// unchanged viewport costs a pointer comparison.

struct ViewportData: Equatable {
    let visibleMonths: [VisibleMonth]

    static let empty = ViewportData(visibleMonths: [])
}

struct VisibleMonth: Equatable {
    let monthOffset: Int
    let yPosition: CGFloat
    let height: CGFloat
    let visibleDays: [VisibleDay]
}

struct VisibleDay: Equatable {
    let daystamp: Daystamp
    let isToday: Bool
    let xPosition: CGFloat
    let yPosition: CGFloat
    let dayNumber: String
}

/// The part of a day that depends only on the calendar, not on layout or scrolling —
/// built once per month and reused by every viewport rebuild.
struct MonthCell {
    let daystamp: Daystamp
    let dayNumber: String
}
