//
//  OvulationTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

final class OvulationDataCodableTests: XCTestCase {

    /// The shape RedCalendar 2.0's Firebase import already wrote, and the only shape any
    /// production row could carry before this feature existed — `confirmed` itself is not
    /// re-checked on the way in (SYNC.md §10.3: `confirmed: false` was never imported).
    func testDecodesTheLegacyConfirmedShape() throws {
        let json = #"{"day":9014,"confirmed":true}"#
        let decoded = try JSONDecoder().decode(OvulationData.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, .confirmed(day: Daystamp(rawValue: 9014)))
    }

    func testEncodesAConfirmedDayWithConfirmedTrue() throws {
        let data = try JSONEncoder().encode(OvulationData.confirmed(day: Daystamp(rawValue: 9014)))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["day"] as? Int, 9014)
        XCTAssertEqual(object?["confirmed"] as? Bool, true)
    }

    func testAnovulatoryRoundTrips() throws {
        let data = try JSONEncoder().encode(OvulationData.anovulatory)
        let decoded = try JSONDecoder().decode(OvulationData.self, from: data)
        XCTAssertEqual(decoded, .anovulatory)
    }

    /// `ovulation: null` is not this type's business at all — it is `CycleRecord.ovulation`
    /// being `nil`, decoded one level up.
    func testNullOvulationDecodesToNilOnTheOptional() throws {
        let json = #"{"start_day":9000,"period_length":5,"ovulation":null}"#
        let record = try JSONDecoder().decode(SyncCycleRow.self, from: Data(json.utf8))
        XCTAssertNil(record.ovulation)
    }
}

final class EffectiveOvulationDayTests: XCTestCase {
    private let settings = ResolvedCycleSettings(nil) // 28/5/14 fallback

    private func cycle(startingAt day: Int, ovulation: OvulationData? = nil) -> CycleRecord {
        CycleRecord(startDay: Daystamp(rawValue: day), periodLength: 5, ovulation: ovulation, dirtySeq: nil)
    }

    /// No next real cycle yet: extrapolated from this cycle's own start.
    func testAutomaticWithNoFollowingCycle() {
        let cycle = cycle(startingAt: 9000)
        XCTAssertEqual(
            cycle.effectiveOvulationDay(nextRealStart: nil, cycleSettings: settings),
            Daystamp(rawValue: 9000 + 28 - 14)
        )
    }

    /// A recorded next start is never predicted over — the luteal phase is measured back from it.
    func testAutomaticAnchorsOffARecordedNextStart() {
        let cycle = cycle(startingAt: 9000)
        let nextStart = Daystamp(rawValue: 9030)
        XCTAssertEqual(
            cycle.effectiveOvulationDay(nextRealStart: nextStart, cycleSettings: settings),
            nextStart.advanced(by: -14)
        )
    }

    /// A confirmed day always wins, whatever the following cycle says.
    func testConfirmedDayWins() {
        let confirmedDay = Daystamp(rawValue: 9010)
        let cycle = cycle(startingAt: 9000, ovulation: .confirmed(day: confirmedDay))
        XCTAssertEqual(
            cycle.effectiveOvulationDay(nextRealStart: Daystamp(rawValue: 9030), cycleSettings: settings),
            confirmedDay
        )
    }

    /// An anovulatory cycle still has an editor day — the same automatic prediction — even though
    /// nothing is drawn there. Without this, "Нет" would have no way back to any other answer.
    func testAnovulatoryStillHasAnEffectiveDay() {
        let cycle = cycle(startingAt: 9000, ovulation: .anovulatory)
        XCTAssertEqual(
            cycle.effectiveOvulationDay(nextRealStart: nil, cycleSettings: settings),
            Daystamp(rawValue: 9000 + 28 - 14)
        )
    }
}

final class AnovulatoryDisplayTests: XCTestCase {
    private let settings = ResolvedCycleSettings(nil) // 28/5/14 fallback

    /// The window disappears — there is nothing to be fertile around — but the day the automatic
    /// prediction would have named still gets its own single-day, unconfirmed marker, so "Нет"
    /// reads as an answer rather than as the day vanishing from the calendar.
    func testAnovulatoryCycleDrawsOnlyTheSingleDayMarker() {
        let cycleStart = Daystamp(rawValue: 9000)
        let ovulationDay = cycleStart.advanced(by: 28 - 14)

        var state = CalendarState()
        state.todayDayStamp = Daystamp(rawValue: 9100)
        state.loadedRange = Daystamp(rawValue: 8900)...Daystamp(rawValue: 9200)
        state.cycles = [CycleRecord(startDay: cycleStart, periodLength: 5, ovulation: .anovulatory, dirtySeq: nil)]

        let result = computeDayDisplayStates(state, cycleSettings: settings)

        XCTAssertEqual(result[ovulationDay]?.fertileWindow?.phase, .ovulation(confirmed: false))
        XCTAssertEqual(result[ovulationDay]?.fertileWindow?.position, .single)

        for offset in [-3, -2, -1, 1] {
            XCTAssertNil(
                result[ovulationDay.advanced(by: offset)]?.fertileWindow,
                "no fertile window at offset \(offset)"
            )
        }
    }
}

final class CanEditOvulationTests: XCTestCase {
    private let settings = ResolvedCycleSettings(nil) // 28/5/14 fallback

    func testEditableOnlyOnTheEffectiveDayAndNotAfterToday() {
        let cycles = [CycleRecord(startDay: Daystamp(rawValue: 9000), periodLength: 5, ovulation: nil, dirtySeq: nil)]
        let effectiveDay = Daystamp(rawValue: 9000 + 28 - 14)

        XCTAssertTrue(
            cycles.dayContext(for: effectiveDay).canEditOvulation(today: effectiveDay, cycleSettings: settings)
        )
        // A neighbouring day is not the editor's day, even though it is not in the future.
        XCTAssertFalse(
            cycles.dayContext(for: effectiveDay - 1).canEditOvulation(today: effectiveDay, cycleSettings: settings)
        )
        // The effective day itself, before it has come — same "no editing the future" rule as
        // the period actions.
        XCTAssertFalse(
            cycles.dayContext(for: effectiveDay).canEditOvulation(today: effectiveDay - 1, cycleSettings: settings)
        )
    }
}
