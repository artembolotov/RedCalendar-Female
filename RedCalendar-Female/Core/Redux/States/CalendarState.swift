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

    /// Changes exactly when `dayDisplayStates` does, and is written in the one place that
    /// writes the dictionary (`appReducer`) — so equal versions mean an identical dictionary.
    ///
    /// It exists so the calendar grid can tell whether it has to redraw without comparing the
    /// dictionary itself. The grid is `Equatable` and is handed to SwiftUI twice per scroll
    /// frame, and this is a map over the whole loaded range: several hundred keys, each with a
    /// `Set` inside it, compared twice a frame to answer a question that has one bit in it.
    var dayDisplayStatesVersion: Int = 0

    /// The last write the database refused, until the user acknowledges it.
    ///
    /// It holds one failure rather than a queue, and the last one wins. A queue would be
    /// describing a situation that does not happen: these are single-row local transactions on a
    /// file the app owns, so a failure means the store itself is in trouble — a disk that is full
    /// or a database that will not open — and the second failure is the first one again. What
    /// matters is that the user learns their edit did not land, once, not that they are told five
    /// times.
    ///
    /// Lives here rather than at the top of `AppState` so that it clears with the rest of the
    /// day data on logout.
    var writeFailure: DataWriteOperation?
}
