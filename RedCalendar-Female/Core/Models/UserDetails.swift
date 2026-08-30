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
    let phoneNumber: String?    // User phone number
    let settings: UserSettings? // User settings (JSONB from database)

    // Convenience computed property for API compatibility
    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "id"
        case name
        case email
        case phoneNumber = "phone_number"
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
        self.phoneNumber = apiUser.phoneNumber
        self.settings = apiUser.settings
    }

    /// Initialize with minimal data (for migration/legacy)
    init(userId: String) {
        self.userId = userId
        self.name = nil
        self.email = nil
        self.phoneNumber = nil
        self.settings = nil
    }

    /// From the local `user_profile` row (SYNC.md §3.1, §12 item 6). `nil` until the row has a
    /// `user_id`, which a sync run writes along with the profile it pulled (§5.1 step 7) — so
    /// before the first successful run there is simply nothing in the table.
    init?(_ record: UserProfileRecord) {
        guard let userId = record.userId else { return nil }
        self.init(
            userId: userId,
            name: record.name,
            email: record.email,
            phoneNumber: record.phoneNumber,
            settings: record.settings
        )
    }
}

// MARK: - API Response Helper (temporary type alias)
// This allows gradual migration from nested UserInfo structs in API responses
typealias APIUserInfo = UserDetails
