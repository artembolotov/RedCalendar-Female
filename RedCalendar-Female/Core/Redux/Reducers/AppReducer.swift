//
//  AppReducer.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import UIKit

func appReducer(state: AppState, action: AppAction) -> AppState {
    var state = state

    switch action {

    case .checkAuthState:
        break

    case .setAuthState(let authState):
        state.authState = authState
        if case .notAuthenticated = authState {
            state.notifications.apnsToken = nil
            state.calendarState = CalendarState()
        }

    case .setAPNSToken(let token):
        state.notifications.apnsToken = token

    case .setPushPermissionState(let permissionState):
        state.notifications.pushPermissionState = permissionState

    case .updateTodayDayStamp:
        state.calendarState.todayDayStamp = Daystamp.today(calendar: .current)

    case .setSelectedDayStamp(let dayStamp):
        state.calendarState.selectedDayStamp = dayStamp

    case .checkAnalyticsStatus:
        break

    case .setAnalyticsActivated(let activated):
        state.analyticsActivated = activated

    case .retryFailedTasks:
        break

    case .logout:
        break
    }

    return state
}
