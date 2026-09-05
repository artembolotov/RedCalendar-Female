//
//  Color+AccentTheme.swift
//  RedCalendar-Female
//

import SwiftUI

// Deliberately not `Color.accent(_:)`: the asset catalog already generates a `Color.accent`
// property, and an overload sharing that name reads as the same thing at the call site while
// resolving to something else.
extension AccentTheme {
    var accent: Color { Color(accentAssetName) }
    var predictedDayText: Color { Color(predictedTextAssetName) }
}
