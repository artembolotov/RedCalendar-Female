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
