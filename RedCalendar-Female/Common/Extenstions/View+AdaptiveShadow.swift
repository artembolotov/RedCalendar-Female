//
//  View+AdaptiveShadow.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 06.09.2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func adaptiveShadow(colorScheme: ColorScheme) -> some View {
        if colorScheme == .dark {
            self
                .shadow(color: Color.white.opacity(0.08), radius: 8, x: 0, y: -4)
        } else {
            self
                .shadow(color: .black.opacity(0.1), radius: 10, x: -2, y: -5)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 2, y: -5)
        }
    }
}
