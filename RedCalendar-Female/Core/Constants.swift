//
//  Constants.swift.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.07.2025.
//
import Foundation

struct Constants {
    struct URLs {
        static let appLink = "https://apps.apple.com/app/redcalendar-cycle-tracker/id1535523842"
        static var api: String {
            Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as! String
        }
    }

    struct Calendar {
        // Days loaded around the calendar center (comments/tags observations + display range)
        static let loadedRangeBuffer = 180
        // Re-center the loaded range when the viewport gets this close to its edge
        static let rangeExpansionThreshold = 30
    }

    struct Cycle {
        static let minCycleLength = 20
        static let maxCycleLength = 90
        static let minPeriodLength = 1
        static let maxPeriodLength = 14

        // Fallbacks when the user has no cycle settings yet
        static let defaultCycleLength = 28
        static let defaultPeriodLength = 5
        static let defaultLutealPhaseLength = 14
    }
}
