//
//  CycleDayContextTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

final class CompletedPeriodEndTests: XCTestCase {
    private func context(day: Int, cycles: [CycleRecord]) -> CycleDayContext {
        cycles.dayContext(for: Daystamp(rawValue: day))
    }

    private func cycle(startingAt day: Int, periodLength: Int?) -> CycleRecord {
        CycleRecord(startDay: Daystamp(rawValue: day), periodLength: periodLength, ovulation: nil, dirtySeq: nil)
    }

    func testOnlyTheLastDayOfAClosedPeriodIsItsEnd() {
        let cycles = [cycle(startingAt: 9000, periodLength: 5)]
        XCTAssertFalse(context(day: 9000, cycles: cycles).isCompletedPeriodEnd)
        XCTAssertFalse(context(day: 9003, cycles: cycles).isCompletedPeriodEnd)
        XCTAssertTrue(context(day: 9004, cycles: cycles).isCompletedPeriodEnd)
        XCTAssertFalse(context(day: 9005, cycles: cycles).isCompletedPeriodEnd)
    }

    func testAOneDayPeriodEndsOnItsStart() {
        let cycles = [cycle(startingAt: 9000, periodLength: 1)]
        XCTAssertTrue(context(day: 9000, cycles: cycles).isCompletedPeriodEnd)
    }

    /// Nothing but `markPeriodEnd` ends a period, so an open one has no end day to report.
    func testAnOpenPeriodHasNoEnd() {
        let cycles = [cycle(startingAt: 9000, periodLength: 0)]
        XCTAssertFalse(context(day: 9004, cycles: cycles).isCompletedPeriodEnd)
    }
}
