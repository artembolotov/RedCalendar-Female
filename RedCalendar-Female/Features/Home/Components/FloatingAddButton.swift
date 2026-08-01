//
//  FloatingAddButton.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 29.07.2025.
//

import SwiftUI

struct FloatingAddButton: View {
    let state: FloatingButtonState
    @Binding var scrollCommand: ScrollCommand
    let onPlusTapped: (() -> Void)?
    
    init(
        state: FloatingButtonState,
        scrollCommand: Binding<ScrollCommand> = .constant(.none),
        onPlusTapped: (() -> Void)? = nil
    ) {
        self.state = state
        self._scrollCommand = scrollCommand
        self.onPlusTapped = onPlusTapped
    }
    
    var body: some View {
        Button(action: {
            handleButtonAction()
        }) {
            AnimatedIcon(state: state)
                .frame(width: 28, height: 28)
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                // A light falling on a solid colour, not a wash of transparency. The gradient
                // this replaces was the accent at 0.8 and 0.9 alpha, so the background showed
                // through its own button — on the dark theme the top corner went visibly grey.
                .background(
                    Circle()
                        .fill(Color.accent)
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.22), Color.white.opacity(0)],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                )
                .shadow(color: Color.accent.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
    
    private func handleButtonAction() {
        switch state {
        case .plus:
            onPlusTapped?()
            
        case .arrowUp, .arrowDown:
            scrollCommand.request()
        }
    }
}

// MARK: - Animated Icon View
struct AnimatedIcon: View {
    let state: FloatingButtonState
    
    private var morphProgress: CGFloat {
        switch state {
        case .arrowDown: return -1    // Chevron down
        case .plus: return 0          // Plus (center)
        case .arrowUp: return 1       // Chevron up
        }
    }
    
    var body: some View {
        MorphingShape(progress: morphProgress)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: morphProgress)
    }
}

// MARK: - Morphing Shape
struct MorphingShape: Shape {
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        let baseLineLength: CGFloat = rect.width * 0.7
        let chevronWidth: CGFloat = rect.width * 0.6
        let chevronHeight: CGFloat = rect.height * 0.35
        
        // Clamp progress to valid range
        let clampedProgress = max(-1, min(1, progress))
        
        // Calculate horizontal line points (always present)
        let horizontalLength = baseLineLength / 2
        
        // Calculate morphing positions
        let leftY: CGFloat
        let rightY: CGFloat
        let centerY: CGFloat
        
        if clampedProgress == 0 {
            // Plus state - horizontal line at center
            leftY = center.y
            rightY = center.y
            centerY = center.y
        } else if clampedProgress > 0 {
            // Morphing towards chevron up
            let morphFactor = clampedProgress
            leftY = center.y + (chevronHeight/2 * morphFactor)
            rightY = center.y + (chevronHeight/2 * morphFactor)
            centerY = center.y - (chevronHeight/2 * morphFactor)
        } else {
            // Morphing towards chevron down
            let morphFactor = abs(clampedProgress)
            let downwardOffset = morphFactor * 2 // 2px offset for better visual balance
            leftY = center.y - (chevronHeight/2 * morphFactor) + downwardOffset
            rightY = center.y - (chevronHeight/2 * morphFactor) + downwardOffset
            centerY = center.y + (chevronHeight/2 * morphFactor) + downwardOffset
        }
        
        // Adjust width for chevron states
        let currentWidth = horizontalLength + (chevronWidth/2 - horizontalLength) * abs(clampedProgress)
        let adjustedLeftX = center.x - currentWidth
        let adjustedRightX = center.x + currentWidth
        
        // Draw horizontal line (morphs into chevron arms)
        path.move(to: CGPoint(x: adjustedLeftX, y: leftY))
        path.addLine(to: CGPoint(x: center.x, y: centerY))
        path.addLine(to: CGPoint(x: adjustedRightX, y: rightY))
        
        // Draw vertical line converging to chevron apex (accelerated disappearance)
        let disappearanceThreshold: CGFloat = 0.75
        let verticalOpacity = max(0, (disappearanceThreshold - abs(clampedProgress)) / disappearanceThreshold)
        
        if verticalOpacity > 0.05 {
            let baseVerticalLength = baseLineLength / 2
            
            // Original vertical line endpoints
            let originalTop = CGPoint(x: center.x, y: center.y - baseVerticalLength)
            let originalBottom = CGPoint(x: center.x, y: center.y + baseVerticalLength)
            
            if clampedProgress > 0 {
                // Morphing to chevron up - both ends converge to chevron apex (top)
                let chevronApex = CGPoint(x: center.x, y: center.y - chevronHeight/2 * clampedProgress)
                
                let topPoint = CGPoint(
                    x: originalTop.x + (chevronApex.x - originalTop.x) * clampedProgress,
                    y: originalTop.y + (chevronApex.y - originalTop.y) * clampedProgress
                )
                let bottomPoint = CGPoint(
                    x: originalBottom.x + (chevronApex.x - originalBottom.x) * clampedProgress,
                    y: originalBottom.y + (chevronApex.y - originalBottom.y) * clampedProgress
                )
                
                path.move(to: topPoint)
                path.addLine(to: bottomPoint)
                
            } else if clampedProgress < 0 {
                // Morphing to chevron down - both ends converge to chevron apex (bottom)
                let morphFactor = abs(clampedProgress)
                let chevronApex = CGPoint(x: center.x, y: center.y + chevronHeight/2 * morphFactor)
                
                let topPoint = CGPoint(
                    x: originalTop.x + (chevronApex.x - originalTop.x) * morphFactor,
                    y: originalTop.y + (chevronApex.y - originalTop.y) * morphFactor
                )
                let bottomPoint = CGPoint(
                    x: originalBottom.x + (chevronApex.x - originalBottom.x) * morphFactor,
                    y: originalBottom.y + (chevronApex.y - originalBottom.y) * morphFactor
                )
                
                path.move(to: topPoint)
                path.addLine(to: bottomPoint)
                
            } else {
                // Plus state - full vertical line
                path.move(to: originalTop)
                path.addLine(to: originalBottom)
            }
        }
        
        return path
    }
}

#Preview {
    VStack(spacing: 30) {
        FloatingAddButton(
            state: .plus
        )
        FloatingAddButton(
            state: .arrowUp
        )
        FloatingAddButton(
            state: .arrowDown
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
