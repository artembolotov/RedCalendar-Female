//
//  UserDetails.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.06.2025.
//

import Foundation

// MARK: - User Details
struct UserDetails: Codable, Equatable {
    let userId: String          // Firebase UID - always present (keeping original field)
    let name: String?           // User name
    let email: String?          // User email
    let settings: UserSettings? // User settings (JSONB from database)
    
    // Convenience computed property for API compatibility
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "id"
        case name
        case email
        case settings
    }
}

// MARK: - User Settings
struct UserSettings: Codable, Equatable {
    let cycle: CycleSettings?
    let predictions: PredictionSettings?
    let notifications: NotificationSettings?

    struct CycleSettings: Codable, Equatable {
        let defaultLength: Int?
        let defaultPeriodLength: Int?
        let lutealPhaseLength: Int?
        
        enum CodingKeys: String, CodingKey {
            case defaultLength = "default_length"
            case defaultPeriodLength = "default_period_length"
            case lutealPhaseLength = "luteal_phase_length"
        }
    }
    
    struct PredictionSettings: Codable, Equatable {
        let enablePeriod: Bool?
        let enableFertile: Bool?
        
        enum CodingKeys: String, CodingKey {
            case enablePeriod = "enable_period"
            case enableFertile = "enable_fertile"
        }
    }
    
    struct NotificationSettings: Codable, Equatable {
        let muted: Bool?
    }
}

// MARK: - Convenience Initializers
extension UserDetails {
    
    /// Initialize from API response data
    init(from apiUser: APIUserInfo) {
        self.userId = apiUser.id
        self.name = apiUser.name
        self.email = apiUser.email
        self.settings = apiUser.settings
    }
    
    /// Initialize with minimal data (for migration/legacy)
    init(userId: String) {
        self.userId = userId
        self.name = nil
        self.email = nil
        self.settings = nil
    }
}

// MARK: - API Response Helper (temporary type alias)
// This allows gradual migration from nested UserInfo structs in API responses
typealias APIUserInfo = UserDetails
