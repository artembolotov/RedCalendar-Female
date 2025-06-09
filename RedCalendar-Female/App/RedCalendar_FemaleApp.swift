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
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear {
                    appDelegate.appStore = store
                    store.send(.checkAuth)
                }
                .onChange(of: scenePhase) { newPhase in
                    store.send(.setPushPermissionState(nil))
                    
                    if newPhase == .active && store.state.isAuthenticated {
                        store.send(.retryFailedTasks)
                    }
                }
        }
    }
}
