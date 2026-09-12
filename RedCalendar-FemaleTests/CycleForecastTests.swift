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

    /// Every expectation below is written against these two, so a change to either should fail
    /// here first rather than in nine cases at once.
    func testTheCasesBelowAssumeTheseConstants() {
        XCTAssertEqual(Constants.Cycle.forecastWindow, 6)
        XCTAssertEqual(Constants.Cycle.forecastMinObservations, 3)
    }

    // MARK: - Cycle Length

    func testNoCyclesMeasureNothing() {
        let forecast = CycleForecast(cycles: [])

        XCTAssertNil(forecast.cycleLength)
        XCTAssertNil(forecast.periodLength)
    }

    /// The guard that protects what the user typed: below the minimum the forecast says nothing
    /// and the stored setting stands.
    func testFewerObservationsThanTheMinimumMeasureNothing() {
        XCTAssertNil(CycleForecast(cycles: cycles(startedEvery: [31, 30])).cycleLength)
    }

    func testTheMinimumNumberOfObservationsIsEnough() {
        XCTAssertEqual(CycleForecast(cycles: cycles(startedEvery: [31, 30, 32])).cycleLength, 31)
    }

    /// The error this data actually contains: a month the user did not record arrives as one
    /// interval of roughly twice the length. An average of these six would answer 36.
    func testAMissedMonthDoesNotMoveTheForecast() {
        XCTAssertEqual(CycleForecast(cycles: cycles(startedEvery: [30, 31, 61, 30, 31, 30])).cycleLength, 30)
    }

    /// Only the last six are measured, so a cycle that genuinely changed is followed rather than
    /// averaged against a year of history.
    func testOnlyTheMostRecentObservationsAreMeasured() {
        let forecast = CycleForecast(cycles: cycles(startedEvery: [28, 28, 28, 40, 41, 39, 40, 41, 40]))

        XCTAssertEqual(forecast.cycleLength, 40)
    }

    /// The lower of the two middles, not their average: a length actually recorded, and the one
    /// that errs early rather than late.
    func testAnEvenNumberOfObservationsTakesTheLowerMiddle() {
        XCTAssertEqual(CycleForecast(cycles: cycles(startedEvery: [28, 30, 33, 40])).cycleLength, 30)
    }

    /// Two things at once, because they are one rule. Intervals this app could not have recorded
    /// — `canStartPeriod` refuses a start closer than `minCycleLength` to another cycle, so these
    /// only reach the table from a RedCalendar 2.0 import — are dropped, and dropped *before* the
    /// window, which is what lets the two 28s before them back in. Taking the window first would
    /// answer 40.
    func testImplausibleIntervalsAreDroppedBeforeTheWindow() {
        XCTAssertEqual(CycleForecast(cycles: cycles(startedEvery: [28, 28, 3, 200, 40, 41, 39, 40])).cycleLength, 39)
    }

    // MARK: - Period Length

    func testPeriodLengthIsTheMedianOfWhatWasRecorded() {
        XCTAssertEqual(CycleForecast(cycles: cycles(withPeriodLengths: [5, 6, 5, 7, 6, 6])).periodLength, 6)
    }

    /// An open period is stored as zero and is not a length: nothing has ended it yet. Three
    /// closed periods remain, which is exactly the minimum.
    func testAnOpenPeriodIsNotMeasured() {
        XCTAssertEqual(CycleForecast(cycles: cycles(withPeriodLengths: [4, 4, 4, 0])).periodLength, 4)
    }

    func testTooFewClosedPeriodsMeasureNothing() {
        XCTAssertNil(CycleForecast(cycles: cycles(withPeriodLengths: [5, 0, 6])).periodLength)
    }

    /// The two halves are measured independently: someone who marks every start but never marks
    /// an end gets a cycle length and keeps their stored period length.
    func testTheTwoLengthsAreMeasuredIndependently() {
        let forecast = CycleForecast(cycles: cycles(startedEvery: [30, 30, 30], periodLength: 0))

        XCTAssertEqual(forecast.cycleLength, 30)
        XCTAssertNil(forecast.periodLength)
    }

    // MARK: - Luteal Phase

    func testNoCyclesMeasureNoLutealPhase() {
        XCTAssertNil(CycleForecast(cycles: []).lutealPhaseLength)
    }

    /// Unlike the two lengths above, one confirmed, completed cycle is already enough — the
    /// luteal phase is close to constant for a given woman, so there is nothing to average it
    /// against.
    func testOneConfirmedCompletedCycleIsEnough() {
        let cycles = [
            cycle(startingAt: 9000, periodLength: 5, ovulation: .confirmed(day: Daystamp(rawValue: 9014))),
            cycle(startingAt: 9028, periodLength: 5)
        ]
        XCTAssertEqual(CycleForecast(cycles: cycles).lutealPhaseLength, 14)
    }

    /// An automatic guess is not a measurement — nothing confirmed it — and an anovulatory cycle
    /// has no ovulation to measure at all.
    func testUnconfirmedAndAnovulatoryCyclesAreNotMeasured() {
        let cycles = [
            cycle(startingAt: 9000, periodLength: 5, ovulation: .anovulatory),
            cycle(startingAt: 9028, periodLength: 5)
        ]
        XCTAssertNil(CycleForecast(cycles: cycles).lutealPhaseLength)
    }

    /// A confirmed ovulation on the cycle still open — no next start recorded — is not a
    /// completed cycle: the distance to "the end" is not a fact yet.
    func testAConfirmedCycleWithNoFollowingStartIsNotMeasured() {
        let cycles = [cycle(startingAt: 9000, periodLength: 5, ovulation: .confirmed(day: Daystamp(rawValue: 9014)))]
        XCTAssertNil(CycleForecast(cycles: cycles).lutealPhaseLength)
    }

    /// The most recent confirmed, completed cycle wins — not a median, and not the first one
    /// found scanning forward.
    func testTheMostRecentConfirmedCompletedCycleWins() {
        let cycles = [
            cycle(startingAt: 9000, periodLength: 5, ovulation: .confirmed(day: Daystamp(rawValue: 9012))),
            cycle(startingAt: 9028, periodLength: 5, ovulation: .confirmed(day: Daystamp(rawValue: 9044))),
            cycle(startingAt: 9058, periodLength: 5)
        ]
        XCTAssertEqual(CycleForecast(cycles: cycles).lutealPhaseLength, 14)
    }

    /// Confirming the wrong day — or a next start recorded weeks late — must not become a
    /// "constant" every future prediction leans on.
    func testAnImplausiblyShortOrLongDistanceIsNotMeasured() {
        let tooShort = [
            cycle(startingAt: 9000, periodLength: 5, ovulation: .confirmed(day: Daystamp(rawValue: 9026))),
            cycle(startingAt: 9028, periodLength: 5)
        ]
        XCTAssertNil(CycleForecast(cycles: tooShort).lutealPhaseLength)

        let tooLong = [
            cycle(startingAt: 9000, periodLength: 5, ovulation: .confirmed(day: Daystamp(rawValue: 9002))),
            cycle(startingAt: 9028, periodLength: 5)
        ]
        XCTAssertNil(CycleForecast(cycles: tooLong).lutealPhaseLength)
    }

    /// The bounds themselves, so a change to `Constants.Cycle.minLutealPhaseLength` /
    /// `maxLutealPhaseLength` fails here first rather than in the two cases above.
    func testTheImplausibleCasesAssumeTheseConstants() {
        XCTAssertEqual(Constants.Cycle.minLutealPhaseLength, 8)
        XCTAssertEqual(Constants.Cycle.maxLutealPhaseLength, 20)
    }

    /// An implausible distance does not forfeit the observation the way a dropped median
    /// candidate would — the scan keeps walking backward for an older, plausible confirmation.
    func testAnImplausibleDistanceFallsBackToAnOlderPlausibleOne() {
        let cycles = [
            cycle(startingAt: 9000, periodLength: 5, ovulation: .confirmed(day: Daystamp(rawValue: 9014))), // 14, plausible
            cycle(startingAt: 9028, periodLength: 5, ovulation: .confirmed(day: Daystamp(rawValue: 9054))), // 2, implausible
            cycle(startingAt: 9056, periodLength: 5)
        ]
        XCTAssertEqual(CycleForecast(cycles: cycles).lutealPhaseLength, 14)
    }

    // MARK: - Helpers

    private func cycle(startingAt day: Int, periodLength: Int, ovulation: OvulationData? = nil) -> CycleRecord {
        CycleRecord(startDay: Daystamp(rawValue: day), periodLength: periodLength, ovulation: ovulation, dirtySeq: nil)
    }

    /// Cycles sorted ascending — the reducer's invariant, which the forecast relies on — built
    /// from the distances between them.
    private func cycles(startedEvery intervals: [Int], periodLength: Int = 5) -> [CycleRecord] {
        var day = 9000
        var records = [cycle(startingAt: day, periodLength: periodLength)]
        for interval in intervals {
            day += interval
            records.append(cycle(startingAt: day, periodLength: periodLength))
        }
        return records
    }

    /// The other direction: cycles far enough apart that their intervals are never the subject,
    /// carrying the period lengths the case is about.
    private func cycles(withPeriodLengths lengths: [Int]) -> [CycleRecord] {
        lengths.enumerated().map { cycle(startingAt: 9000 + $0.offset * 30, periodLength: $0.element) }
    }
}
