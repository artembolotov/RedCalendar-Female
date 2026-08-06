//
//  RedCalendar_FemaleApp.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

@main
struct RedCalendarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var store = AppStore(
        initialState: AppState(),
        reducer: appReducer,
        middlewares: combineAppMiddlewares()
    )

    init() {
        Configurator.shared.setup()
    }

    private func clearNotifications() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // The one place the chosen accent enters the environment. Everything tinted
                // rather than filled — navigation bars, buttons, pickers, sheets — inherits it
                // from here, so no view below needs its own `.tint`.
                .tint(store.state.accentTheme.accent)
                .environmentObject(store)
                .onAppear {
                    appDelegate.appStore = store
                    store.send(.checkAuthState)
                    store.send(.checkAnalyticsStatus)
                    store.send(.checkAccentTheme)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        store.send(.updateTodayDayStamp)
                        store.send(.setPushPermissionState(nil))
                        store.send(.retryFailedTasks)

                        clearNotifications()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    store.send(.updateTodayDayStamp)
                }
        }
    }
}
