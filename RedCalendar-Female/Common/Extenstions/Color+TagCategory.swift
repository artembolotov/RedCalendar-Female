//
//  Color+TagCategory.swift
//  RedCalendar-Female
//

import SwiftUI

extension Color {
    static func tagColor(for category: Int?) -> Color {
        switch category {
        case 0: return .blue
        case 1: return .green
        case 2: return Color(red: 0.20, green: 0.73, blue: 0.68)
        case 3: return .purple
        default: return .gray
        }
    }
}
