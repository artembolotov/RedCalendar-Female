//
//  CalendarState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.08.2025.
//

struct CalendarState: Equatable {
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
}
