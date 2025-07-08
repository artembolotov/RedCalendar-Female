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
}
