//
//  InfiniteScrollContainer.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.08.2025.
//

import SwiftUI

struct InfiniteScrollContainer: UIViewRepresentable {
    @Binding var scrollOffset: CGFloat
    @Binding var scrollCommand: ScrollCommand
    
    let onScrollChanged: (CGFloat) -> Void
    let onDragStateChanged: (Bool) -> Void
    let onDayTapped: (Date) -> Void
    let initialCenterOffset: CGFloat
    let calculator: MonthCalculator
    let currentDate: Date
    
    private let contentHeight: CGFloat = 8000000
    private let centerY: CGFloat = 4000000
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.contentSize = CGSize(width: 0, height: contentHeight)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.isMultipleTouchEnabled = true
        scrollView.canCancelContentTouches = true
        scrollView.delaysContentTouches = false
        scrollView.backgroundColor = .clear
        scrollView.scrollsToTop = false
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        tapGesture.require(toFail: scrollView.panGestureRecognizer)
        scrollView.addGestureRecognizer(tapGesture)
        
        scrollView.contentOffset.y = centerY - initialCenterOffset
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.updateCurrentDate(currentDate)
        context.coordinator.updateCalculator(calculator)
        context.coordinator.updateScrollOffset(scrollOffset)
        
        if scrollCommand == .animateToCenter {
            let targetY = centerY - initialCenterOffset
            
            let duration = TimeInterval(0.7)
            
            // Start smooth animation using CADisplayLink
            context.coordinator.startAnimation(to: targetY, in: uiView, duration: duration)
            
            DispatchQueue.main.async {
                scrollCommand = .none
            }
            return
        }
        
        if !context.coordinator.isDragging {
            let targetY = centerY - scrollOffset
            let currentY = uiView.contentOffset.y
            let difference = abs(currentY - targetY)
            
            if difference > 1 {
                uiView.contentOffset.y = targetY
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let parent: InfiniteScrollContainer
        var isDragging = false
        var lastRecenter = Date()
        private var currentDate: Date
        private var calculator: MonthCalculator
        private var currentScrollOffset: CGFloat = 0
        
        // Animation properties
        private var displayLink: CADisplayLink?
        private var animationStartTime: CFTimeInterval = 0
        private var animationDuration: TimeInterval = 0
        private var animationStartOffset: CGFloat = 0
        private var animationTargetOffset: CGFloat = 0
        private weak var animatingScrollView: UIScrollView?
        
        init(_ parent: InfiniteScrollContainer) {
            self.parent = parent
            self.currentDate = parent.currentDate
            self.calculator = parent.calculator
        }
        
        deinit {
            stopAnimation()
        }
        
        func updateCurrentDate(_ date: Date) {
            self.currentDate = date
        }
        
        func updateCalculator(_ calc: MonthCalculator) {
            self.calculator = calc
        }
        
        func updateScrollOffset(_ offset: CGFloat) {
            self.currentScrollOffset = offset
        }
        
        // MARK: - Animation Methods
        
        func startAnimation(to targetY: CGFloat, in scrollView: UIScrollView, duration: TimeInterval) {
            stopAnimation()
            
            // Stop any active scroll/deceleration
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)
            
            animationStartOffset = scrollView.contentOffset.y
            animationTargetOffset = targetY
            animationDuration = duration
            animationStartTime = CACurrentMediaTime()
            animatingScrollView = scrollView
            
            displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        func stopAnimation() {
            displayLink?.invalidate()
            displayLink = nil
            animatingScrollView = nil
        }
        
        @objc private func updateAnimation() {
            guard let scrollView = animatingScrollView else {
                stopAnimation()
                return
            }
            
            let currentTime = CACurrentMediaTime()
            let elapsed = currentTime - animationStartTime
            
            if elapsed >= animationDuration {
                // Animation complete
                scrollView.contentOffset.y = animationTargetOffset
                stopAnimation()
                return
            }
            
            // Spring physics with natural bounce
            let progress = elapsed / animationDuration
            let springProgress = springInterpolation(progress)
            
            let delta = animationTargetOffset - animationStartOffset
            let newOffset = animationStartOffset + (delta * springProgress)
            
            scrollView.contentOffset.y = newOffset
        }
        
        // Underdamped spring interpolation (iOS-like)
        private func springInterpolation(_ t: Double) -> Double {
            guard t > 0 else { return 0 }
            guard t < 1 else { return 1 }
            
            // Spring parameters
            let damping: Double = 0.85        // 0.7-0.8 gives nice bounce
            let mass: Double = 1.0
            let stiffness: Double = 100.0
            let velocity: Double = 0.0
            
            let c = damping * 2.0 * sqrt(mass * stiffness)
            let omega = sqrt(stiffness / mass)
            let zeta = c / (2.0 * sqrt(stiffness * mass))
            
            // Underdamped case (zeta < 1)
            if zeta < 1.0 {
                let omegaD = omega * sqrt(1.0 - zeta * zeta)
                let exponential = exp(-zeta * omega * t)
                let cosine = cos(omegaD * t)
                let sine = sin(omegaD * t)
                let A = 1.0
                let B = (zeta * omega + velocity) / omegaD
                
                return 1.0 - exponential * (A * cosine + B * sine)
            }
            
            // Fallback to critically damped
            return 1.0 - exp(-omega * t) * (1.0 + omega * t)
        }
        
        // MARK: - Tap Handler
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            
            let tapLocation = gesture.location(in: scrollView)
            
            // Calculate calendar coordinates
            let calendarY = tapLocation.y - parent.centerY + currentScrollOffset
            
            // Find which day was tapped using ViewportCalculator
            if let tappedDate = findDayAt(calendarY: calendarY, tapX: tapLocation.x, scrollView: scrollView) {
                parent.onDayTapped(tappedDate)
            }
        }
        
        private func findDayAt(calendarY: CGFloat, tapX: CGFloat, scrollView: UIScrollView) -> Date? {
            let screenWidth = scrollView.bounds.width
            let screenHeight = scrollView.bounds.height
            
            // Keep original coordinate system logic
            let dynamicViewport = ViewportCalculator.calculateDynamicViewport(
                scrollOffset: currentScrollOffset,
                screenHeight: screenHeight,
                screenWidth: screenWidth,
                calculator: calculator,
                currentDate: currentDate,
                calendar: Calendar.current
            )
            
            let horizontalPadding = CalendarConstants.horizontalPadding
            let dayWidth = (screenWidth - horizontalPadding) / 7
            
            // Calculate day of week once (0-6)
            let dayOfWeek = Int(tapX / dayWidth)
            guard dayOfWeek >= 0 && dayOfWeek < 7 else { return nil }
            
            let tapCalendarY = calendarY - currentScrollOffset
            
            // Optimize: find month first, then calculate day mathematically
            for month in dynamicViewport.visibleMonths {
                let weeksCount = calculator.getWeeksCount(for: month.monthOffset)
                
                // Use proper constants instead of magic numbers
                let headerHeight = CalendarConstants.monthHeaderHeight
                let weekSpacing = CalendarConstants.gridVerticalSpacing
                
                let gridStartY = month.yPosition + headerHeight
                let gridEndY = gridStartY + CGFloat(weeksCount) * (calculator.weekHeight + weekSpacing)
                
                // Check if tap is within the month grid area
                if tapCalendarY >= gridStartY - calculator.weekHeight / 2 &&
                   tapCalendarY <= gridEndY + calculator.weekHeight / 2 {
                    
                    // Calculate which week was tapped using same formula as ViewportCalculator
                    let relativeY = tapCalendarY - gridStartY
                    let weekIndex = Int(relativeY / (calculator.weekHeight + weekSpacing))
                    
                    // Get the specific day directly from month days array
                    let monthDays = calculator.getMonthDays(for: month.monthOffset)
                    let dayIndex = weekIndex * 7 + dayOfWeek
                    
                    guard dayIndex >= 0 && dayIndex < monthDays.count else { return nil }
                    
                    return monthDays[dayIndex]
                }
            }
            
            return nil
        }
        
        // MARK: - UIGestureRecognizerDelegate
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        // MARK: - UIScrollViewDelegate methods
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let physicalY = scrollView.contentOffset.y
            var calendarOffset = self.parent.centerY - physicalY
            
            let limits = self.parent.calculator.getScrollLimits()
            let originalOffset = calendarOffset
            calendarOffset = max(limits.min, min(limits.max, calendarOffset))
            
            if originalOffset != calendarOffset {
                let correctedPhysicalY = self.parent.centerY - calendarOffset
                scrollView.contentOffset.y = correctedPhysicalY
                
                DispatchQueue.main.async {
                    self.parent.scrollOffset = calendarOffset
                    self.parent.onScrollChanged(calendarOffset)
                }
                return
            }
            
            if !isDragging && currentDate.timeIntervalSince(lastRecenter) > 5.0 {
                let correctedPhysicalY = self.parent.centerY - calendarOffset
                let distanceFromEdge = min(correctedPhysicalY, self.parent.contentHeight - correctedPhysicalY)
                if distanceFromEdge < 100000 {
                    scrollView.contentOffset.y = self.parent.centerY - calendarOffset
                    lastRecenter = currentDate
                }
            }
            
            DispatchQueue.main.async {
                self.parent.scrollOffset = calendarOffset
                self.parent.onScrollChanged(calendarOffset)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            // Stop any active animation
            stopAnimation()
            
            isDragging = true
            DispatchQueue.main.async { self.parent.onDragStateChanged(true) }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
            if !willDecelerate {
                isDragging = false
                
                let physicalY = scrollView.contentOffset.y
                var calendarOffset = self.parent.centerY - physicalY
                let limits = self.parent.calculator.getScrollLimits()
                let correctedOffset = max(limits.min, min(limits.max, calendarOffset))
                
                if abs(correctedOffset - calendarOffset) > 0.1 {
                    let correctedPhysicalY = self.parent.centerY - correctedOffset
                    scrollView.contentOffset.y = correctedPhysicalY
                    calendarOffset = correctedOffset
                }
                
                DispatchQueue.main.async {
                    self.parent.scrollOffset = calendarOffset
                    self.parent.onScrollChanged(calendarOffset)
                    self.parent.onDragStateChanged(false)
                }
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isDragging = false
            
            let physicalY = scrollView.contentOffset.y
            var calendarOffset = self.parent.centerY - physicalY
            let limits = self.parent.calculator.getScrollLimits()
            let correctedOffset = max(limits.min, min(limits.max, calendarOffset))
            
            if abs(correctedOffset - calendarOffset) > 0.1 {
                let correctedPhysicalY = self.parent.centerY - correctedOffset
                scrollView.contentOffset.y = correctedPhysicalY
                calendarOffset = correctedOffset
            }
            
            DispatchQueue.main.async {
                self.parent.scrollOffset = calendarOffset
                self.parent.onScrollChanged(calendarOffset)
                self.parent.onDragStateChanged(false)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let targetPhysicalY = targetContentOffset.pointee.y
            let targetCalendarOffset = parent.centerY - targetPhysicalY
            
            let limits = parent.calculator.getScrollLimits()
            
            let boundaryBuffer: CGFloat = 200
            let isApproachingTop = targetCalendarOffset > (limits.max - boundaryBuffer)
            let isApproachingBottom = targetCalendarOffset < (limits.min + boundaryBuffer)
            
            if isApproachingTop || isApproachingBottom {
                let clampedTarget = max(limits.min, min(limits.max, targetCalendarOffset))
                
                if isApproachingTop && targetCalendarOffset > limits.max {
                    let overshoot = targetCalendarOffset - limits.max
                    let dampenedOvershoot = overshoot * 0.3
                    let smoothTarget = limits.max + dampenedOvershoot
                    targetContentOffset.pointee.y = parent.centerY - smoothTarget
                } else if isApproachingBottom && targetCalendarOffset < limits.min {
                    let overshoot = limits.min - targetCalendarOffset
                    let dampenedOvershoot = overshoot * 0.3
                    let smoothTarget = limits.min - dampenedOvershoot
                    targetContentOffset.pointee.y = parent.centerY - smoothTarget
                } else {
                    let correctedPhysicalY = parent.centerY - clampedTarget
                    targetContentOffset.pointee.y = correctedPhysicalY
                }
                
                scrollView.decelerationRate = UIScrollView.DecelerationRate.fast
            } else {
                scrollView.decelerationRate = UIScrollView.DecelerationRate.normal
            }
        }
    }
}
