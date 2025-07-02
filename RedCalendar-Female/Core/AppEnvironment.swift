//
//  Environment.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 02.07.2025.
//

// Core/Environment.swift
import Foundation

class AppEnvironment {
    static let shared = AppEnvironment()
    
    private init() {}
    
    // Read from Info.plist (set by .xcconfig)
    var apiBaseURL: String {
        return Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "https://api.calendar.red"
    }
    
    var environmentName: String {
        return Bundle.main.object(forInfoDictionaryKey: "ENVIRONMENT_NAME") as? String ?? "Production"
    }
    
    var isProduction: Bool {
        return environmentName == "Production"
    }
    
    var isStaging: Bool {
        return environmentName == "Staging"
    }
    
    // For debugging
    func printEnvironmentInfo() {
        print("🌐 Environment: \(environmentName)")
        print("🔗 API URL: \(apiBaseURL)")
        print("📱 Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
    }
}
