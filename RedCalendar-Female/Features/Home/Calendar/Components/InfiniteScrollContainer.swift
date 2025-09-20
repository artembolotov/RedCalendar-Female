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
    let onDayTapped: (Date) -> Void // Add this callback
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
           uiView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
           
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
        
        init(_ parent: InfiniteScrollContainer) {
            self.parent = parent
            self.currentDate = parent.currentDate
            self.calculator = parent.calculator
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
            
            for month in dynamicViewport.visibleMonths {
                for day in month.visibleDays {
                    // Check if tap is within day bounds
                    let dayLeft = day.xPosition
                    let dayRight = day.xPosition + dayWidth
                    let dayTop = day.yPosition - calculator.weekHeight / 2
                    let dayBottom = day.yPosition + calculator.weekHeight / 2
                    
                    let tapCalendarY = calendarY - currentScrollOffset
                    
                    if tapX >= dayLeft && tapX <= dayRight &&
                       tapCalendarY >= dayTop && tapCalendarY <= dayBottom {
                        return day.date
                    }
                }
            }
            
            return nil
        }
        
        // MARK: - UIGestureRecognizerDelegate
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true // Allow tap gesture to work with scroll gestures
        }
        
        // MARK: - UIScrollViewDelegate methods (unchanged)
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
