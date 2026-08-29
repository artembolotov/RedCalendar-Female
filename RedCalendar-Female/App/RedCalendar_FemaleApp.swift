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

    /// Observed, not owned: the store belongs to the process now (SYNC.md §8), and the scene is
    /// only one of its readers. `@StateObject` over an already-built singleton keeps the
    /// observation exactly as it was — including `.tint(store.state.accentTheme.accent)` in this
    /// body, which a plain stored property would stop updating.
    @StateObject private var store = AppStore.shared

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
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        store.send(.calendar(.updateToday))
                        store.send(.push(.checkPermissionState))
                        store.send(.retryFailedTasks)

                        clearNotifications()
                    }

                    // Flushes the 3-second debounce rather than adding another trigger: an edit
                    // made in the last moment before the app is put away would otherwise wait for
                    // whatever happens next, which may be days (SYNC.md §5.6). The run itself
                    // holds a background task assertion, so it gets to finish.
                    if newPhase == .background {
                        store.send(.sync(.requested(.appBackground)))
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    store.send(.calendar(.updateToday))
                }
        }
    }
}
