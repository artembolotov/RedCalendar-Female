//
//  Shape+AdaptiveBackground.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on [current date].
//

import SwiftUI

extension Shape {
    @ViewBuilder
    func adaptiveBackground(colorScheme: ColorScheme) -> some View {
        if colorScheme == .dark {
            self.fill(.regularMaterial)
        } else {
            self.fill(Color(.systemBackground))
        }
    }
}
