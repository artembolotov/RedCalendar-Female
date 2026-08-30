//
//  SyncProfilePushTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// The defect these exist for: the server reads `changes.profile` by `hasOwnProperty`, so
/// `name: null` means "erase the name" and an absent `name` means "leave it alone" (SYNC.md §4.5,
/// `pickProfileFields`). `AccountView` edits the name now, but `nameDirtySeq` is what still keeps
/// this safe on a profile dirtied for some other reason: a device whose profile has not been
/// pulled yet has no real name to send, and encoding the row's own `name` unconditionally would
/// erase the name given at registration, on the server, for every device.
final class SyncProfilePushTests: XCTestCase {

    private func encodedKeys(_ push: SyncProfilePush) throws -> [String: JSONValue] {
        let data = try JSONEncoder().encode(push)
        return try JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    /// The row is dirty (a settings edit did it), but nothing has touched the name —
    /// `nameDirtySeq` is what tells `init(_:)` not to read it into the push.
    func testAProfileDirtiedBySettingsAloneDoesNotSendTheName() throws {
        let record = UserProfileRecord(
            id: 1,
            userId: "abc",
            name: "Анна",
            email: "a@example.com",
            phoneNumber: "+70000000000",
            settingsJSON: #"{"cycle":{"default_length":30}}"#,
            dirtySeq: 7
        )

        let json = try encodedKeys(SyncProfilePush(record))

        XCTAssertNil(json["name"], "an absent key is what leaves the server's name alone")
        XCTAssertNotNil(json["settings"])
    }

    /// The counterpart: `nameDirtySeq` set is what makes `init(_:)` read the row's own name into
    /// the push at all — this is `AccountView`'s write path, end to end.
    func testAProfileWithNameDirtySeqSendsTheName() throws {
        let record = UserProfileRecord(
            id: 1,
            userId: "abc",
            name: "Анна",
            email: "a@example.com",
            phoneNumber: "+70000000000",
            settingsJSON: nil,
            dirtySeq: 9,
            nameDirtySeq: 9
        )

        let json = try encodedKeys(SyncProfilePush(record))

        XCTAssertEqual(json["name"], .string("Анна"))
    }

    /// A name cleared back to empty is stored locally as `nil` — the same tombstone every other
    /// soft-deleted field in this app uses — and with `nameDirtySeq` set that has to reach the
    /// server as an explicit erase, not as an absent key.
    func testAClearedNameIsSentAsAnExplicitErase() throws {
        let record = UserProfileRecord(
            id: 1,
            userId: "abc",
            name: nil,
            email: "a@example.com",
            phoneNumber: "+70000000000",
            settingsJSON: nil,
            dirtySeq: 9,
            nameDirtySeq: 9
        )

        let json = try encodedKeys(SyncProfilePush(record))

        XCTAssertEqual(json["name"], JSONValue.null)
    }

    /// The distinction the double optional carries: absent is not the same as null, and only the
    /// second one erases.
    func testAnAbsentNameAndANullNameAreDifferentOnTheWire() throws {
        let notEditing = try encodedKeys(SyncProfilePush(name: nil, settings: .object([:])))
        let erasing = try encodedKeys(SyncProfilePush(name: .some(nil), settings: .object([:])))

        XCTAssertNil(notEditing["name"])
        XCTAssertEqual(erasing["name"], JSONValue.null)
    }

    func testANameBeingEditedIsSent() throws {
        let json = try encodedKeys(SyncProfilePush(name: .some("Анна"), settings: nil))

        XCTAssertEqual(json["name"], .string("Анна"))
        XCTAssertNil(json["settings"], "nothing is editing the settings in this push")
    }

    /// Identity is the server's alone (§4.4), and leaving those fields out of the type is how that
    /// is said once rather than hoped for.
    func testIdentityFieldsAreNeverEncoded() throws {
        let record = UserProfileRecord(
            id: 1,
            userId: "abc",
            name: "Анна",
            email: "a@example.com",
            phoneNumber: "+70000000000",
            settingsJSON: #"{"cycle":{"default_length":30}}"#,
            dirtySeq: 7
        )

        let json = try encodedKeys(SyncProfilePush(record))

        XCTAssertNil(json["email"])
        XCTAssertNil(json["phone_number"])
        XCTAssertNil(json["id"])
        XCTAssertNil(json["user_id"])
    }

    /// The settings travel as whatever JSON is in the column, keys this build does not model
    /// included — that is the whole reason they are carried as `JSONValue`.
    func testSettingsTravelWholeIncludingUnmodelledKeys() throws {
        let record = UserProfileRecord(
            id: 1,
            userId: "abc",
            name: nil,
            email: nil,
            phoneNumber: nil,
            settingsJSON: #"{"cycle":{"default_length":30},"something_future":{"kept":1}}"#,
            dirtySeq: 7
        )

        let json = try encodedKeys(SyncProfilePush(record))

        XCTAssertEqual(
            json["settings"],
            JSONValue(jsonString: #"{"cycle":{"default_length":30},"something_future":{"kept":1}}"#)
        )
    }

    func testAnUnreadableSettingsColumnOmitsTheKeyRatherThanSendingNull() throws {
        let record = UserProfileRecord(
            id: 1,
            userId: "abc",
            name: nil,
            email: nil,
            phoneNumber: nil,
            settingsJSON: nil,
            dirtySeq: 7
        )

        let json = try encodedKeys(SyncProfilePush(record))

        XCTAssertTrue(json.isEmpty, "a push with nothing to say must not claim to erase anything")
    }

    /// `UserProfileRecord.settings` is what feeds `.setCycleSettings`, and it has to work on a row
    /// that carries no `user_id` — the row a settings edit creates before the first sync run.
    func testARowWithoutAnIdStillYieldsItsCycleSettings() {
        let record = UserProfileRecord(
            id: 1,
            userId: nil,
            name: nil,
            email: nil,
            phoneNumber: nil,
            settingsJSON: #"{"cycle":{"default_length":30,"default_period_length":6}}"#,
            dirtySeq: 3
        )

        XCTAssertNil(UserDetails(record), "no user_id means no identity")

        let resolved = ResolvedCycleSettings(record.settings?.cycle)
        XCTAssertEqual(resolved.cycleLength, 30)
        XCTAssertEqual(resolved.periodLength, 6)
    }
}
