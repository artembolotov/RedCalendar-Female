//
//  JSONValueMergeTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// `JSONValue.setting(_:to:)` is what keeps a local settings edit from deleting the rest of the
/// profile. The server replaces `settings` wholesale, so whatever this build fails to put back is
/// gone from every device (SYNC.md §15) — these tests pin the merge, not the arithmetic.
final class JSONValueMergeTests: XCTestCase {

    // The shape a real profile arrives in: two keys this build models and one it does not.
    private let stored = """
        {"cycle":{"default_length":26,"luteal_phase_length":14},\
        "predictions":{"enable_period":true},\
        "something_future":{"kept":1}}
        """

    func testMergeKeepsKeysThisBuildDoesNotModel() throws {
        let settings = try XCTUnwrap(JSONValue(jsonString: stored))

        let merged = settings.setting(["cycle", "default_length"], to: .int(30))

        guard case .object(let root) = merged else {
            return XCTFail("merging into an object must produce an object")
        }
        XCTAssertEqual(root["predictions"], .object(["enable_period": .bool(true)]))
        XCTAssertEqual(root["something_future"], .object(["kept": .int(1)]))
    }

    func testMergeReplacesOnlyTheAddressedLeaf() throws {
        let settings = try XCTUnwrap(JSONValue(jsonString: stored))

        let merged = settings.setting(["cycle", "default_length"], to: .int(30))

        XCTAssertEqual(
            merged,
            JSONValue(jsonString: """
                {"cycle":{"default_length":30,"luteal_phase_length":14},\
                "predictions":{"enable_period":true},\
                "something_future":{"kept":1}}
                """)
        )
    }

    /// The mechanism `DatabaseService.updateLutealPhaseLength(nil)` relies on to clear
    /// `luteal_phase_length` back to unset when `CycleForecast` no longer supports a measurement:
    /// the key is removed outright, not overwritten with `null` — the row ends up exactly as it
    /// would be if ovulation had never been confirmed at all.
    func testRemovingSettingDeletesTheKeyOutright() throws {
        let settings = try XCTUnwrap(JSONValue(jsonString: stored))

        let merged = settings.removingSetting(["cycle", "luteal_phase_length"])

        guard case .object(let root) = merged, case .object(let cycle)? = root["cycle"] else {
            return XCTFail("removing from an object must produce an object")
        }
        XCTAssertNil(cycle["luteal_phase_length"], "the key itself must be gone, not merely null")
        // The rest of the document survives the removal untouched.
        XCTAssertEqual(cycle["default_length"], .int(26))
        XCTAssertEqual(root["predictions"], .object(["enable_period": .bool(true)]))
    }

    /// Removing a key that was never there, or descending through a path whose intermediate key
    /// is absent, is a no-op — it must not manufacture the structure `setting(_:to:)` would have.
    func testRemovingAMissingKeyIsANoOp() throws {
        let settings = try XCTUnwrap(JSONValue(jsonString: stored))

        XCTAssertEqual(settings.removingSetting(["cycle", "never_written"]), settings)
        XCTAssertEqual(settings.removingSetting(["absent_scope", "leaf"]), settings)
    }

    /// A scalar has nothing to remove a key from — it survives untouched, the same rule
    /// `setting(_:to:)` follows for the opposite direction (§4.5).
    func testRemovingFromANonObjectIsANoOp() {
        XCTAssertEqual(JSONValue.int(5).removingSetting(["cycle", "luteal_phase_length"]), .int(5))
    }

    /// The other half of the same mechanism: an absent key decodes to `nil` on
    /// `UserSettings.CycleSettings.lutealPhaseLength`, which is what lets `ResolvedCycleSettings`
    /// fall back to `Constants.Cycle.defaultLutealPhaseLength` once the key has been removed.
    func testARemovedLutealPhaseDecodesToNil() throws {
        let settings = try XCTUnwrap(JSONValue(jsonString: stored))
        let merged = settings.removingSetting(["cycle", "luteal_phase_length"])

        let record = UserProfileRecord(
            id: 1, userId: nil, name: nil, email: nil, phoneNumber: nil,
            settingsJSON: merged.jsonString, dirtySeq: nil
        )

        XCTAssertNil(record.settings?.cycle?.lutealPhaseLength)
        // The removal did not disturb the sibling key it shares an object with.
        XCTAssertEqual(record.settings?.cycle?.defaultLength, 26)
    }

    func testMergeCreatesAMissingPath() {
        let merged = JSONValue.object([:]).setting(["cycle", "default_period_length"], to: .int(6))

        XCTAssertEqual(merged, .object(["cycle": .object(["default_period_length": .int(6)])]))
    }

    /// A scalar `settings` is the case §4.5 says the client has to survive. Surviving it means
    /// carrying it through untouched — and there is nothing left to carry once the user has asked
    /// for a key to be stored inside it.
    func testMergeReplacesANonObjectOnThePath() {
        let merged = JSONValue.int(5).setting(["cycle", "default_length"], to: .int(28))

        XCTAssertEqual(merged, .object(["cycle": .object(["default_length": .int(28)])]))
    }

    /// `settings_json` is compared as a string by `UserProfileRecord.==`, which is the question
    /// `removeDuplicates()` asks of the profile observation. A Swift dictionary iterates in a
    /// seed-randomised order, so without sorted keys the same settings could re-encode to a
    /// different string and wake every reader of the profile.
    func testJSONStringSortsKeys() {
        let value = JSONValue.object(["c": .int(3), "a": .int(1), "b": .int(2)])

        XCTAssertEqual(value.jsonString, #"{"a":1,"b":2,"c":3}"#)
    }

    func testJSONStringIsStableAcrossEncodings() throws {
        let settings = try XCTUnwrap(JSONValue(jsonString: stored))

        let first = try XCTUnwrap(settings.jsonString)
        let second = try XCTUnwrap(JSONValue(jsonString: first)?.jsonString)

        XCTAssertEqual(first, second)
    }

    func testDecodingKeepsIntegersAsIntegers() throws {
        // A JSON 28.0 does not fit the `Int` that `UserSettings.CycleSettings` decodes into: the
        // decode would throw and the cycle length would silently fall back to 28.
        let settings = try XCTUnwrap(JSONValue(jsonString: stored))

        guard case .object(let root) = settings,
              case .object(let cycle)? = root["cycle"] else {
            return XCTFail("the stored profile is an object of objects")
        }
        XCTAssertEqual(cycle["default_length"], .int(26))
    }
}
