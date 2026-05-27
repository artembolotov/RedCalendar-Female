//
//  AppAction.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

enum AppAction {
    // Auth actions
    case checkAuthState
    case setAuthState(_ state: AuthState)
    case logout
    
    // Calendar actions
    case updateTodayDayStamp
    case setSelectedDayStamp(_ dayStamp: Daystamp?)

    // Database → Store
    case setCycles(_ cycles: [CycleRecord])
    case setUserTags(_ tags: [UserTagRecord])
    case setVisibleComments(_ comments: [Daystamp: CommentRecord])
    case setVisibleDayTags(_ dayTags: [Daystamp: [String]])
    case setLoadedRange(_ range: ClosedRange<Daystamp>)

    // CalendarView → DatabaseMiddleware
    case calendarScrolledTo(center: Daystamp)
    
    // Push notification actions
    case setAPNSToken(_ token: APNSToken)
    case setPushPermissionState(_ state: PushPermissionState?)
    
    // Analytics actions
    case checkAnalyticsStatus
    case setAnalyticsActivated(_ activated: Bool)

    // Retry actions
    case retryFailedTasks
}
