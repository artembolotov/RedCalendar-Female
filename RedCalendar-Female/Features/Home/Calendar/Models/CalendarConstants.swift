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
    // How far the calendar may slide before its day cells are rebuilt for a new anchor.
    // Must stay well below the buffer below, which is what keeps the leading edge covered
    // in the meantime.
    static let viewportUpdateThreshold: CGFloat = 120
    // Day cells are built for the screen plus this share of its height above and below.
    // It absorbs the drift between two rebuilds — a tighter buffer shows empty rows
    // sliding in at the leading edge of a fast scroll.
    static let dayVisibilityBufferRatio: CGFloat = 0.6
    static let averageMonthHeight: CGFloat = 290

    // MARK: - Day rendering
    static let periodBarHeight: CGFloat = 26
    static let periodBarCornerRadius: CGFloat = 8
    static let dayIndicatorSize: CGFloat = 32
    static let fertileLineBottomInset: CGFloat = 4
    static let fertileLineWidth: CGFloat = 2
    static let tagDotSize: CGFloat = 6
    static let tagDotSpacing: CGFloat = 3
    static let tagDotsOffset: CGFloat = 14

    // MARK: - Month limits for infinite scroll
    static let minMonthOffset: Int = -2400
    static let maxMonthOffset: Int = 2400
}
