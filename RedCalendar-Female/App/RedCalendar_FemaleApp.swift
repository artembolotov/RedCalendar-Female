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
                    // Pass store reference to AppDelegate
                    appDelegate.appStore = store
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        // App became active - check auth or retry failed tasks
                        if store.state.isAuthenticated {
                            // User is already authenticated - retry failed tasks
                            store.send(.retryFailedTasks)
                        } else {
                            // User not authenticated - check auth first
                            store.send(.checkAuth)
                        }
                    }
                }
        }
    }
}
