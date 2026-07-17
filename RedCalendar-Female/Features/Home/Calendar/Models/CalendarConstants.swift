//
//  CalendarConstants.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.08.2025.
//
import Foundation

enum CalendarConstants {
    static let weekdaysHeaderHeight: CGFloat = 31
    static let horizontalPadding: CGFloat = 24
    
    // MARK: - Month Header
    static let monthHeaderHeight: CGFloat = 60
    
    // MARK: - Grid
    static let gridVerticalSpacing: CGFloat = 4
    static let bottomSpacing: CGFloat = 20
    
    // MARK: - Viewport
    static let viewportUpdateThreshold: CGFloat = 30
    static let dayVisibilityBuffer: CGFloat = 100
    static let averageMonthHeight: CGFloat = 290
    
    // MARK: - Month limits for infinite scroll
    static let minMonthOffset: Int = -2400
    static let maxMonthOffset: Int = 2400
}
