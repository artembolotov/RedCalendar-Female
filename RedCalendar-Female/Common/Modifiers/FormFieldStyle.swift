//
//  FormFieldStyleModifier.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 20.06.2025.
//

import SwiftUI

// MARK: - Form Field Style Modifier
struct FormFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

// MARK: - View Extension
extension View {
    func formFieldStyle() -> some View {
        modifier(FormFieldStyle())
    }
}
