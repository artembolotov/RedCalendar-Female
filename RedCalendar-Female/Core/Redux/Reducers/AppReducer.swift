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
        state.calendarState.dayDisplayStates = computeDayDisplayStates(state.calendarState, cycleSettings: state.currentUser?.settings?.cycle)

    case .setSelectedDayStamp(let dayStamp):
        state.calendarState.selectedDayStamp = dayStamp

    case .setCycles(let cycles):
        state.calendarState.cycles = cycles
        state.calendarState.dayDisplayStates = computeDayDisplayStates(state.calendarState, cycleSettings: state.currentUser?.settings?.cycle)

    case .setUserTags(let tags):
        state.calendarState.userTags = tags
        state.calendarState.dayDisplayStates = computeDayDisplayStates(state.calendarState, cycleSettings: state.currentUser?.settings?.cycle)

    case .setVisibleComments(let comments):
        state.calendarState.visibleComments = comments
        state.calendarState.dayDisplayStates = computeDayDisplayStates(state.calendarState, cycleSettings: state.currentUser?.settings?.cycle)

    case .setVisibleDayTags(let dayTags):
        state.calendarState.visibleDayTags = dayTags
        state.calendarState.dayDisplayStates = computeDayDisplayStates(state.calendarState, cycleSettings: state.currentUser?.settings?.cycle)

    case .setLoadedRange(let range):
        state.calendarState.loadedRange = range
        state.calendarState.dayDisplayStates = computeDayDisplayStates(state.calendarState, cycleSettings: state.currentUser?.settings?.cycle)

    case .calendarScrolledTo:
        break

    case .markPeriodStart,
         .markPeriodEnd,
         .unmarkPeriodEnd,
         .setFlowLevel,
         .saveComment,
         .setDayTags:
        break

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
