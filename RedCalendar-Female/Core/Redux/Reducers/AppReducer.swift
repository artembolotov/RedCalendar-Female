//
//  AppReducer.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import UIKit

func appReducer(state: AppState, action: AppAction) -> AppState {
    var state = state
    var recomputeDayDisplayStates = false

    switch action {

    case .checkAuthState:
        break

    case .setAuthState(let authState):
        state.authState = authState
        if case .notAuthenticated = authState {
            state.notifications.apnsToken = nil
            state.calendarState = CalendarState()
        }
        // Cycle settings ride along with the user details, so display states have to be
        // rebuilt here too — otherwise settings changed on the server only take effect
        // at the next unrelated cycle/tag/comment change.
        recomputeDayDisplayStates = true

    case .setAPNSToken(let token):
        state.notifications.apnsToken = token

    case .setPushPermissionState(let permissionState):
        state.notifications.pushPermissionState = permissionState

    case .updateTodayDayStamp:
        state.calendarState.todayDayStamp = Daystamp.today(calendar: .current)
        recomputeDayDisplayStates = true

    case .setSelectedDayStamp(let dayStamp):
        state.calendarState.selectedDayStamp = dayStamp

    case .setCycles(let cycles):
        // Sorted-by-startDay invariant: cycle queries and the display computer
        // rely on this order (see CycleRecord+Queries).
        state.calendarState.cycles = cycles.sorted { $0.startDay < $1.startDay }
        recomputeDayDisplayStates = true

    case .setUserTags(let tags):
        state.calendarState.userTags = tags
        recomputeDayDisplayStates = true

    case .setVisibleComments(let comments):
        state.calendarState.visibleComments = comments
        recomputeDayDisplayStates = true

    case .setVisibleDayTags(let dayTags):
        state.calendarState.visibleDayTags = dayTags
        recomputeDayDisplayStates = true

    case .setLoadedRange(let range):
        state.calendarState.loadedRange = range
        recomputeDayDisplayStates = true

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

    if recomputeDayDisplayStates {
        state.calendarState.dayDisplayStates = computeDayDisplayStates(
            state.calendarState,
            cycleSettings: ResolvedCycleSettings(state.currentUser?.settings?.cycle)
        )
    }

    return state
}
