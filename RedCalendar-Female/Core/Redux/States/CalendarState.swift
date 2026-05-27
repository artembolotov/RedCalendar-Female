//
//  CalendarState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.08.2025.
//

struct CalendarState {
    var todayDayStamp: Daystamp = Daystamp.today(calendar: .current)
    var selectedDayStamp: Daystamp?

    // Loaded range (center of calendar ± 6 months buffer)
    var loadedRange: ClosedRange<Daystamp> = {
        let today = Daystamp.today(calendar: .current)
        return (today - 180)...(today + 180)
    }()

    // Raw data from GRDB
    var cycles: [CycleRecord] = []
    var userTags: [UserTagRecord] = []
    var visibleComments: [Daystamp: CommentRecord] = [:]
    var visibleDayTags: [Daystamp: [String]] = [:]

    // Computed from raw data — never set directly via action
    var dayDisplayStates: [Daystamp: DayDisplayState] = [:]
}
