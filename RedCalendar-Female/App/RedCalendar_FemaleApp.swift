//
//  RedCalendar_FemaleApp.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

@main
struct RedCalendarApp: App {
    @StateObject private var store = AppStore(
        initialState: AppState(),
        reducer: appReducer,
        middleware: authMiddleware
    )
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear {
                    store.send(.checkAuth)
                }
        }
    }
}
