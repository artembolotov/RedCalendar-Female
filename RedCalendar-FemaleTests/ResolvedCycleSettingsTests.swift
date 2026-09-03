//
//  ResolvedCycleSettingsTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// The clamp exists so that the prediction loop terminates and `predictedCycleStart` does not
/// divide by zero. `settings` is validated for shape and not for contents (SYNC.md §4.5), so the
/// column can hand back any number a client ever wrote there — these are the shapes that would
/// hang or crash the drawing if it were trusted.
final class ResolvedCycleSettingsTests: XCTestCase {

    func testFallbacksWhenThereAreNoSettings() {
        let resolved = ResolvedCycleSettings(nil)

        XCTAssertEqual(resolved.cycleLength, Constants.Cycle.defaultCycleLength)
        XCTAssertEqual(resolved.periodLength, Constants.Cycle.defaultPeriodLength)
        XCTAssertEqual(resolved.lutealPhaseLength, Constants.Cycle.defaultLutealPhaseLength)
        XCTAssertEqual(resolved.autoConfirmPreviousCycle, Constants.Cycle.defaultAutoConfirmPreviousCycle)
    }

    func testAutoConfirmPreviousCycleReadsTheStoredChoice() {
        let resolved = ResolvedCycleSettings(
            UserSettings.CycleSettings(
                defaultLength: nil,
                defaultPeriodLength: nil,
                lutealPhaseLength: nil,
                autoConfirmPreviousCycle: false
            )
        )

        XCTAssertFalse(resolved.autoConfirmPreviousCycle)
    }

    func testFallbacksPerFieldWhenOnlySomeArePresent() {
        let resolved = ResolvedCycleSettings(
            UserSettings.CycleSettings(defaultLength: 31, defaultPeriodLength: nil, lutealPhaseLength: nil)
        )

        XCTAssertEqual(resolved.cycleLength, 31)
        XCTAssertEqual(resolved.periodLength, Constants.Cycle.defaultPeriodLength)
        XCTAssertEqual(resolved.lutealPhaseLength, Constants.Cycle.defaultLutealPhaseLength)
    }

    /// A stored value below this app's own minimum is *shown* clamped and never written back on
    /// appear — the screen must not turn its own opinion into the user's stored choice.
    func testACycleLengthBelowTheMinimumIsClampedForDisplay() {
        let resolved = ResolvedCycleSettings(
            UserSettings.CycleSettings(defaultLength: 19, defaultPeriodLength: nil, lutealPhaseLength: nil)
        )

        XCTAssertEqual(resolved.cycleLength, Constants.Cycle.minCycleLength)
    }

    func testCycleLengthIsClampedAtBothEnds() {
        XCTAssertEqual(
            ResolvedCycleSettings(
                UserSettings.CycleSettings(defaultLength: 0, defaultPeriodLength: nil, lutealPhaseLength: nil)
            ).cycleLength,
            Constants.Cycle.minCycleLength
        )
        XCTAssertEqual(
            ResolvedCycleSettings(
                UserSettings.CycleSettings(defaultLength: 400, defaultPeriodLength: nil, lutealPhaseLength: nil)
            ).cycleLength,
            Constants.Cycle.maxCycleLength
        )
    }

    /// A 16-day period is in the imported cycle data, against this app's maximum of 14 — the same
    /// gap between what may arrive and what may be entered.
    func testPeriodLengthIsClampedAtBothEnds() {
        XCTAssertEqual(
            ResolvedCycleSettings(
                UserSettings.CycleSettings(defaultLength: nil, defaultPeriodLength: 0, lutealPhaseLength: nil)
            ).periodLength,
            Constants.Cycle.minPeriodLength
        )
        XCTAssertEqual(
            ResolvedCycleSettings(
                UserSettings.CycleSettings(defaultLength: nil, defaultPeriodLength: 16, lutealPhaseLength: nil)
            ).periodLength,
            Constants.Cycle.maxPeriodLength
        )
    }

    /// The luteal phase has to leave at least one day of follicular phase, or ovulation lands on
    /// or before the cycle start. Its upper bound is a function of the cycle length, which is why
    /// this is not a constant.
    func testLutealPhaseLeavesAtLeastOneFollicularDay() {
        let resolved = ResolvedCycleSettings(
            UserSettings.CycleSettings(defaultLength: 20, defaultPeriodLength: nil, lutealPhaseLength: 25)
        )

        XCTAssertEqual(resolved.cycleLength, 20)
        XCTAssertEqual(resolved.lutealPhaseLength, 19)
    }

    func testLutealPhaseIsClampedAgainstTheClampedCycleLength() {
        // The cycle length is clamped first, so the luteal bound follows the clamped 20, not 19.
        let resolved = ResolvedCycleSettings(
            UserSettings.CycleSettings(defaultLength: 19, defaultPeriodLength: nil, lutealPhaseLength: 30)
        )

        XCTAssertEqual(resolved.lutealPhaseLength, Constants.Cycle.minCycleLength - 1)
    }

    func testZeroLutealPhaseIsRaisedToOne() {
        let resolved = ResolvedCycleSettings(
            UserSettings.CycleSettings(defaultLength: 28, defaultPeriodLength: nil, lutealPhaseLength: 0)
        )

        XCTAssertEqual(resolved.lutealPhaseLength, 1)
    }

    /// Ovulation is `cycleLength - lutealPhaseLength` days after the start; the invariant above is
    /// what keeps that strictly inside the cycle for every input.
    func testOvulationAlwaysLandsInsideTheCycle() {
        for cycle in [0, 19, 20, 28, 90, 400] {
            for luteal in [0, 1, 14, 25, 100] {
                let resolved = ResolvedCycleSettings(
                    UserSettings.CycleSettings(
                        defaultLength: cycle,
                        defaultPeriodLength: nil,
                        lutealPhaseLength: luteal
                    )
                )
                let ovulationOffset = resolved.cycleLength - resolved.lutealPhaseLength
                XCTAssertGreaterThan(ovulationOffset, 0, "cycle \(cycle), luteal \(luteal)")
                XCTAssertLessThan(ovulationOffset, resolved.cycleLength, "cycle \(cycle), luteal \(luteal)")
            }
        }
    }
}
