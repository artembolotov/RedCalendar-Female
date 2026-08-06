//
//  AppAction.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

enum AppAction: Sendable {
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
    case setVisibleComments(_ comments: [Daystamp: String])
    case setVisibleDayTags(_ dayTags: [Daystamp: [String]])
    case setLoadedRange(_ range: ClosedRange<Daystamp>)

    // CalendarView → DatabaseMiddleware
    case calendarScrolledTo(center: Daystamp)

    // Day editing
    case markPeriodStart(_ dayStamp: Daystamp)
    case markPeriodEnd(_ dayStamp: Daystamp)
    case unmarkPeriodEnd(_ dayStamp: Daystamp)
    case setFlowLevel(_ dayStamp: Daystamp, _ level: Int?)
    case saveComment(_ dayStamp: Daystamp, _ text: String)
    case setDayTags(_ dayStamp: Daystamp, _ tagIds: [String])
    
    // Push notification actions
    case setAPNSToken(_ token: APNSToken)
    case setPushPermissionState(_ state: PushPermissionState?)
    
    // Analytics actions
    case checkAnalyticsStatus
    case setAnalyticsActivated(_ activated: Bool)

    // Appearance actions
    case checkAccentTheme
    case setAccentTheme(_ theme: AccentTheme)

    // Retry actions
    case retryFailedTasks
}
