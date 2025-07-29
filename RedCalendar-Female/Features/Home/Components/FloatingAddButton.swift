//
//  FloatingAddButton.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 29.07.2025.
//

import SwiftUI

struct FloatingAddButton: View {
    let state: FloatingButtonState
    
    var body: some View {
        Button(action: {
            handleButtonAction()
        }) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(0.8),
                            Color.accentColor,
                            Color.accentColor.opacity(0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
    
    private var iconName: String {
        switch state {
        case .plus:
            return "plus"
        case .arrowUp:
            return "arrow.up"
        case .arrowDown:
            return "arrow.down"
        }
    }
    
    private func handleButtonAction() {
        switch state {
        case .plus:
            print("Add button tapped")
            
        case .arrowUp, .arrowDown:
            scrollToToday()
        }
    }
    
    private func scrollToToday() {
        print("Scroll to today requested - direction: \(state)")
        // TODO: Implement scroll to today functionality
    }
}
