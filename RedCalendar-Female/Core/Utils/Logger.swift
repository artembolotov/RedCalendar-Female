//
//  Logger.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

struct AppLogger {
    static func action(_ action: AppAction) {
        #if DEBUG
        print("🎯 Action: \(action)")
        #endif
    }
    
    static func stateChange<T>(_ keyPath: String, oldValue: T, newValue: T) {
        #if DEBUG
        print("📊 State.\(keyPath): \(oldValue) → \(newValue)")
        #endif
    }
    
    static func error(_ message: String, error: Error? = nil) {
        #if DEBUG
        print("❌ Error: \(message)")
        if let error = error {
            print("   Details: \(error.localizedDescription)")
        }
        #endif
        
        @Injected var analytics: AnalyticsServiceProtocol
        analytics.trackEvent("app_error", parameters: ["message": message])
    }
}
