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
                .tint(.accent)
                .environmentObject(store)
                .onAppear {
                    appDelegate.appStore = store
                    store.send(.checkAuthState)
                    store.send(.checkAnalyticsStatus)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        store.send(.setPushPermissionState(nil))
                        store.send(.retryFailedTasks)
                        
                        clearNotifications()
                    }
                }
        }
    }
}
