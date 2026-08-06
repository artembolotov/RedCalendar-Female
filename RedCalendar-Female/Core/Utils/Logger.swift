//
//  Logger.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

/// `nonisolated`: a log line is written where the thing being logged happened, and that is as often
/// the nonisolated keychain or API service as it is a view. Isolating this to the main actor would
/// turn every `AppLogger.error(…)` in those files into an `await`.
nonisolated struct AppLogger {
    static func action(_ action: AppAction) {
        #if DEBUG
        print("🎯 Action: \(action)")
        #endif
    }
    
    static func info(_ message: String) {
        #if DEBUG
        print("ℹ️ INFO: \(message)")
        #endif
    }
    
    static func warn(_ message: String) {
        #if DEBUG
        print("⚠️ WARN: \(message)")
        #endif

        analytics.trackEvent("app_warning", parameters: ["message": message])
    }

    static func error(_ message: String, error: Error? = nil) {
        #if DEBUG
        print("❌ ERROR: \(message)")
        if let error = error {
            print("   Details: \(error.localizedDescription)")
        }
        #endif

        analytics.trackEvent("app_error", parameters: ["message": message])
    }

    /// The one place that resolves through the container rather than through `@Injected`. The
    /// wrapper takes the module's main-actor default — it has to, since a local variable inherits
    /// its wrapper's isolation and `nonisolated` on a local is an error — and this type is
    /// nonisolated, because a log line is written wherever the thing being logged happened. Same
    /// lookup, same per-read laziness, no wrapper.
    private static var analytics: AnalyticsServiceProtocol {
        ServiceLocator.shared.getService()
    }
}
