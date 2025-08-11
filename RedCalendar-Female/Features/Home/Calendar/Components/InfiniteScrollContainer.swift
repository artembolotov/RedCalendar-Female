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
        
        scrollView.contentOffset.y = centerY - initialCenterOffset
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.updateCurrentDate(currentDate)
        
        if scrollCommand == .animateToCenter {
           let targetY = centerY - initialCenterOffset
           uiView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
           
           // Команда выполнена - сбрасываем
           DispatchQueue.main.async {
               scrollCommand = .none
           }
           return // Важно! Не продолжаем к обычной синхронизации
       }
        
        if !context.coordinator.isDragging {
            let targetY = centerY - scrollOffset
            let currentY = uiView.contentOffset.y
            let difference = abs(currentY - targetY)
            
            let weekHeight = calculator.weekHeight
            
            if difference > weekHeight * 2 {
                uiView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
            } else {
                uiView.contentOffset.y = targetY
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: InfiniteScrollContainer
        var isDragging = false
        var lastRecenter = Date()
        private var currentDate: Date
        
        init(_ parent: InfiniteScrollContainer) {
            self.parent = parent
            self.currentDate = parent.currentDate
        }
        
        func updateCurrentDate(_ date: Date) {
            self.currentDate = date
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let physicalY = scrollView.contentOffset.y
            var calendarOffset = self.parent.centerY - physicalY
            
            let limits = self.parent.calculator.getScrollLimits()
            let originalOffset = calendarOffset
            calendarOffset = max(limits.min, min(limits.max, calendarOffset))
            
            if originalOffset != calendarOffset {
                let correctedPhysicalY = self.parent.centerY - calendarOffset
                scrollView.contentOffset.y = correctedPhysicalY
                
                self.parent.scrollOffset = calendarOffset
                self.parent.onScrollChanged(calendarOffset)
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
                
                self.parent.scrollOffset = calendarOffset
                self.parent.onScrollChanged(calendarOffset)
                
                DispatchQueue.main.async {
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
            
            self.parent.scrollOffset = calendarOffset
            self.parent.onScrollChanged(calendarOffset)
            
            DispatchQueue.main.async {
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
