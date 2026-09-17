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

/// How long an open period has run as the calendar draws it — the rule the period bar and
/// `DatabaseMiddleware`'s auto-confirm both have to answer the same way.
///
/// Auto-confirm used to close a period at the bare forecast. Reported flow lengthens an open
/// period's bar, so for anyone whose period ran longer than her forecast that tap shrank the bar
/// it had just confirmed, dropped the flow days out of the period entirely, and handed
/// `CycleForecast` a length the rows beneath it contradicted — which it then measured as an
/// observation, so the forecast could never learn a longer period from her.
final class DrawnPeriodLengthTests: XCTestCase {

    private let start = Daystamp(rawValue: 9000)
    private lazy var cycle = CycleRecord(startDay: start, periodLength: 0, ovulation: nil)

    private func length(flowOn days: [Int], forecast: Int = 5, today: Int = 9020) -> Int {
        let flow = Dictionary(uniqueKeysWithValues: days.map { (Daystamp(rawValue: $0), 2) })
        return flow.drawnPeriodLength(of: cycle, notAfter: Daystamp(rawValue: today),
                                      forecast: forecast)
    }

    func testWithNoFlowItIsTheForecast() {
        XCTAssertEqual(length(flowOn: []), 5)
    }

    /// Flow lengthens the forecast and never shortens it — nothing but `markPeriodEnd` ends a
    /// period, so three days of reported flow do not make it a three-day period.
    func testFlowInsideTheForecastDoesNotShortenIt() {
        XCTAssertEqual(length(flowOn: [9000, 9001, 9002]), 5)
    }

    func testFlowPastTheForecastLengthensIt() {
        XCTAssertEqual(length(flowOn: [9005]), 6)
        XCTAssertEqual(length(flowOn: [9000, 9007]), 8)
    }

    /// The window is the cycle's own days, at most `maxPeriodLength` of them: a day of flow
    /// beyond it belongs to no period anyone would draw.
    func testFlowBeyondTheWindowIsNotCounted() {
        XCTAssertEqual(length(flowOn: [start.rawValue + Constants.Cycle.maxPeriodLength - 1]),
                       Constants.Cycle.maxPeriodLength)
        XCTAssertEqual(length(flowOn: [start.rawValue + Constants.Cycle.maxPeriodLength]), 5)
    }

    /// And never past today, so flow synced from a device a day ahead cannot stretch a period
    /// into days that have not happened.
    func testFlowAfterTodayIsNotCounted() {
        XCTAssertEqual(length(flowOn: [9007], today: 9006), 5)
        XCTAssertEqual(length(flowOn: [9007], today: 9007), 8)
    }
}
