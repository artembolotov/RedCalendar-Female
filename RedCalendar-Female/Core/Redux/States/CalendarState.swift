//
//  CalendarState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.08.2025.
//

struct CalendarState: Equatable, Sendable {
    var todayDayStamp: Daystamp = Daystamp.today(calendar: .current)
    var selectedDayStamp: Daystamp?

    // Loaded range (center of calendar ± buffer)
    var loadedRange: ClosedRange<Daystamp> = {
        let today = Daystamp.today(calendar: .current)
        let buffer = Constants.Calendar.loadedRangeBuffer
        return (today - buffer)...(today + buffer)
    }()

    // Raw data from GRDB
    var cycles: [CycleRecord] = []
    var userTags: [UserTagRecord] = []
    var visibleComments: [Daystamp: String] = [:]
    var visibleDayTags: [Daystamp: [String]] = [:]

    // Computed from raw data — never set directly via action
    var dayDisplayStates: [Daystamp: DayDisplayState] = [:]

    /// Changes exactly when `dayDisplayStates` does, and is written in the one place that
    /// writes the dictionary (`appReducer`) — so equal versions mean an identical dictionary.
    ///
    /// It exists so the calendar grid can tell whether it has to redraw without comparing the
    /// dictionary itself. The grid is `Equatable` and is handed to SwiftUI twice per scroll
    /// frame, and this is a map over the whole loaded range: several hundred keys, each with a
    /// `Set` inside it, compared twice a frame to answer a question that has one bit in it.
    var dayDisplayStatesVersion: Int = 0
}
