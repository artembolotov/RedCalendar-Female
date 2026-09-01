//
//  NotificationPreferenceTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// The distinction these pin is the one that decides whether the app is allowed to put the system
/// permission alert on screen — a question iOS only lets anybody ask once per install.
///
/// "No profile row yet" and "a row that says nothing about notifications" are both an absent
/// `muted`, and they mean opposite things: the first is a returning user whose settings have not
/// been pulled, who may have muted notifications on another device and must not be asked on a
/// guess; the second is every account imported from RedCalendar 2.0 (SYNC.md §10.2), whose
/// silence has always meant on.
final class NotificationPreferenceTests: XCTestCase {

    private func record(settingsJSON: String?) -> UserProfileRecord {
        UserProfileRecord(
            id: 1,
            userId: "abc",
            name: nil,
            email: nil,
            phoneNumber: nil,
            settingsJSON: settingsJSON,
            dirtySeq: nil
        )
    }

    func testNoProfileRowIsUnknownRatherThanEnabled() {
        XCTAssertEqual(NotificationPreference(nil), .unknown)
    }

    func testARowWithoutSettingsMeansEnabled() {
        XCTAssertEqual(NotificationPreference(record(settingsJSON: nil)), .enabled)
    }

    /// The imported-2.0 shape: cycle settings and nothing else.
    func testARowWithoutANotificationsKeyMeansEnabled() {
        let stored = #"{"cycle":{"default_length":28}}"#
        XCTAssertEqual(NotificationPreference(record(settingsJSON: stored)), .enabled)
    }

    func testMutedTrueIsHonoured() {
        let stored = #"{"cycle":{"default_length":28},"notifications":{"muted":true}}"#
        XCTAssertEqual(NotificationPreference(record(settingsJSON: stored)), .muted)
    }

    func testMutedFalseIsEnabled() {
        let stored = #"{"notifications":{"muted":false}}"#
        XCTAssertEqual(NotificationPreference(record(settingsJSON: stored)), .enabled)
    }

    /// `settings` is checked for shape and not for contents (§4.5), so the column can hold
    /// anything a client ever wrote there. Nothing about that is worth failing a profile over:
    /// `UserProfileRecord.settings` gives up and returns `nil`, which is the same silence as a
    /// row that never mentioned notifications.
    func testUnreadableSettingsFallBackToEnabledRatherThanUnknown() {
        XCTAssertEqual(NotificationPreference(record(settingsJSON: #""just a string""#)), .enabled)
    }

    // MARK: - What the switch and the permission rule read

    func testTheSwitchDrawsOffOnlyForAMutedAccount() {
        var state = NotificationState(preference: .enabled)
        state.pushPermissionState = .authorized
        XCTAssertTrue(state.isEnabledOnThisDevice)

        state.preference = .muted
        XCTAssertFalse(state.isEnabledOnThisDevice)

        // Not read yet reads as on — the same default an absent key means.
        state.preference = .unknown
        XCTAssertTrue(state.isEnabledOnThisDevice)
    }

    func testASystemDenialTurnsTheSwitchOffWithoutTouchingThePreference() {
        var state = NotificationState(preference: .enabled)
        state.pushPermissionState = .denied

        XCTAssertFalse(state.isEnabledOnThisDevice)
        XCTAssertTrue(state.isAllowedByPreference, "the account's own answer is this device's to read, not to rewrite")
        XCTAssertFalse(state.shouldRequestSystemPermission, "a denial is final until the Settings app undoes it")
    }

    func testPermissionIsAskedForOnlyWhenTheAccountHasActuallyAskedForIt() {
        var state = NotificationState(preference: .unknown)
        state.pushPermissionState = .notAsked
        XCTAssertFalse(state.shouldRequestSystemPermission, "a profile that has not been pulled is not consent")

        state.preference = .muted
        XCTAssertFalse(state.shouldRequestSystemPermission)

        state.preference = .enabled
        XCTAssertTrue(state.shouldRequestSystemPermission)

        state.pushPermissionState = .authorized
        XCTAssertFalse(state.shouldRequestSystemPermission, "already answered")

        state.pushPermissionState = nil
        XCTAssertFalse(state.shouldRequestSystemPermission, "the system state has not been read yet")
    }
}
