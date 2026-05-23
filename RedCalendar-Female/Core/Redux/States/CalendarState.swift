//
//  CalendarState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.08.2025.
//

struct CalendarState {
    var todayDayStamp: Daystamp = Daystamp.today(calendar: .current)
    var selectedDayStamp: Daystamp?
}
