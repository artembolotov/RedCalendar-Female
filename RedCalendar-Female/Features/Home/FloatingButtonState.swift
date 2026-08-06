//
//  FloatingButtonState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 29.07.2025.
//

import SwiftUI

// MARK: - Button State Enum
enum FloatingButtonState: Equatable {
    case plus        // Today is visible - show plus
    case arrowUp     // Today went below viewport - show arrow up
    case arrowDown   // Today went above viewport - show arrow down
}

// MARK: - PreferenceKey for state communication
struct TodayVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: FloatingButtonState { .plus }
    
    static func reduce(value: inout FloatingButtonState, nextValue: () -> FloatingButtonState) {
        value = nextValue()
    }
}
