//
//  CycleForecastTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// The forecast replaces a number the user chose, so the cases that matter are the ones where it
/// must decline to — and the ones where the data it measures is wrong in the ways this data is
/// actually wrong: a month nobody recorded, a period never closed, a history imported from an app
/// with different rules.
final class CycleForecastTests: XCTestCase {

    // MARK: - Cycle Length

    func testNoCyclesMeasureNothing() {
        let forecast = CycleForecast(cycles: [])

        XCTAssertNil(forecast.cycleLength)
        XCTAssertNil(forecast.periodLength)
    }

    /// One recorded start is not one observation — a cycle's length is the distance to the next
    /// start, so the first cycle only becomes measurable once a second one exists.
    func testASingleCycleMeasuresNothing() {
        XCTAssertNil(CycleForecast(cycles: [cycle(startingAt: 9000, periodLength: 5)]).cycleLength)
    }

    /// The guard that protects what the user typed: below the minimum the forecast says nothing
    /// and the stored setting stands.
    func testFewerObservationsThanTheMinimumMeasureNothing() {
        let forecast = CycleForecast(cycles: cycles(startedEvery: [31, 30]))

        XCTAssertEqual(Constants.Cycle.forecastMinObservations, 3, "the case below is written against three")
        XCTAssertNil(forecast.cycleLength)
    }

    func testTheMinimumNumberOfObservationsIsEnough() {
        XCTAssertEqual(CycleForecast(cycles: cycles(startedEvery: [31, 30, 32])).cycleLength, 31)
    }

    /// The error this data actually contains: a month the user did not record arrives as one
    /// interval of roughly twice the length. An average of these six would answer 36.
    func testAMissedMonthDoesNotMoveTheForecast() {
        XCTAssertEqual(CycleForecast(cycles: cycles(startedEvery: [30, 31, 61, 30, 31, 30])).cycleLength, 30)
    }

    /// Only the last `forecastWindow` are measured, so a cycle that genuinely changed is followed
    /// rather than averaged against a year of history.
    func testOnlyTheMostRecentObservationsAreMeasured() {
        let forecast = CycleForecast(cycles: cycles(startedEvery: [28, 28, 28, 40, 41, 39, 40, 41, 40]))

        XCTAssertEqual(Constants.Cycle.forecastWindow, 6, "the case above is written against six")
        XCTAssertEqual(forecast.cycleLength, 40)
    }

    /// The lower of the two middles, not their average: a length actually recorded, and the one
    /// that errs early rather than late.
    func testAnEvenNumberOfObservationsTakesTheLowerMiddle() {
        XCTAssertEqual(CycleForecast(cycles: cycles(startedEvery: [28, 30, 33, 40])).cycleLength, 30)
    }

    /// `canStartPeriod` makes this impossible to record on a device — a start closer than
    /// `minCycleLength` to another cycle is refused — but a history imported from RedCalendar 2.0
    /// was written by an app that did not enforce it.
    func testImplausibleIntervalsAreNotMeasured() {
        let forecast = CycleForecast(cycles: cycles(startedEvery: [3, 30, 200, 31, 30, 29]))

        XCTAssertEqual(forecast.cycleLength, 30)
    }

    /// What is measured is the last six *plausible* observations, not what survives of the last
    /// six cycles: the two dropped here make room for the two 28s before them, which is what
    /// pulls the answer down to 39. Taking the window first would answer 40.
    func testTheWindowIsFilledFromPlausibleObservationsOnly() {
        let forecast = CycleForecast(cycles: cycles(startedEvery: [28, 28, 3, 200, 40, 41, 39, 40]))

        XCTAssertEqual(forecast.cycleLength, 39)
    }

    // MARK: - Period Length

    func testPeriodLengthIsTheMedianOfWhatWasRecorded() {
        let recorded = [5, 6, 5, 7, 6, 6].enumerated().map {
            cycle(startingAt: 9000 + $0.offset * 30, periodLength: $0.element)
        }

        XCTAssertEqual(CycleForecast(cycles: recorded).periodLength, 6)
    }

    /// An open period is stored as zero and is not a length: nothing has ended it yet. Three
    /// closed periods remain, which is exactly the minimum.
    func testAnOpenPeriodIsNotMeasured() {
        let recorded = [
            cycle(startingAt: 9000, periodLength: 4),
            cycle(startingAt: 9030, periodLength: 4),
            cycle(startingAt: 9060, periodLength: 4),
            cycle(startingAt: 9090, periodLength: 0)
        ]

        XCTAssertEqual(CycleForecast(cycles: recorded).periodLength, 4)
    }

    func testTooFewClosedPeriodsMeasureNothing() {
        let recorded = [
            cycle(startingAt: 9000, periodLength: 5),
            cycle(startingAt: 9030, periodLength: 0),
            cycle(startingAt: 9060, periodLength: 6)
        ]

        XCTAssertNil(CycleForecast(cycles: recorded).periodLength)
    }

    /// The two halves are measured independently: a person who marks every start but rarely marks
    /// an end gets a cycle length and keeps their stored period length.
    func testTheTwoLengthsAreMeasuredIndependently() {
        let recorded = cycles(startedEvery: [30, 30, 30]).map { cycle(startingAt: $0.startDay.rawValue, periodLength: 0) }

        let forecast = CycleForecast(cycles: recorded)
        XCTAssertEqual(forecast.cycleLength, 30)
        XCTAssertNil(forecast.periodLength)
    }

    // MARK: - Helpers

    private func cycle(startingAt day: Int, periodLength: Int) -> CycleRecord {
        CycleRecord(startDay: Daystamp(rawValue: day), periodLength: periodLength, ovulation: nil, dirtySeq: nil)
    }

    /// Cycles sorted ascending — the reducer's invariant, which the forecast relies on — from the
    /// distances between them.
    private func cycles(startedEvery intervals: [Int]) -> [CycleRecord] {
        var day = 9000
        var records = [cycle(startingAt: day, periodLength: 5)]
        for interval in intervals {
            day += interval
            records.append(cycle(startingAt: day, periodLength: 5))
        }
        return records
    }
}
