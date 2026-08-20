//
//  Color+TagCategory.swift
//  RedCalendar-Female
//

import SwiftUI

// The colour lives here rather than on `TagCategory` itself for the reason `Color+AccentTheme`
// gives: the model layer names the thing, the extension in `Common` says what colour it is.
extension TagCategory {
    var color: Color {
        switch self {
        case .symptom:    return .blue
        case .mood:       return .green
        case .activity:   return Color(red: 0.20, green: 0.73, blue: 0.68)
        case .medication: return .purple
        }
    }
}

extension Color {
    /// Still takes the raw integer, and still answers for values `TagCategory` does not cover:
    /// a tag with no category, or one from a build that knew more of them than this one does,
    /// is drawn grey instead of being dropped.
    static func tagColor(for category: Int?) -> Color {
        category.flatMap(TagCategory.init(rawValue:))?.color ?? .gray
    }
}
