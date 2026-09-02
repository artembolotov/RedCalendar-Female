//
//  DevicesReducerTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// What the device list's reducer decides (SYNC.md §19).
///
/// Three of these have no visible failure mode. A list that survives a reopen shows sessions that
/// may have been ended from another phone since — the one thing a list of live sessions must not
/// do. An answer that lands after the screen closed and rebuilds the state puts a screen's worth
/// of data back with nobody looking at it, exactly as `emailBinding` refuses to. And a failed
/// revocation that forgets to clear the in-flight mark leaves a row that can never be swiped
/// again without leaving the screen.
final class DevicesReducerTests: XCTestCase {

    private let current = "current-device-id"
    private let other = "other-device-id"

    private func loadedState() -> AppState {
        var state = AppState(authState: .authenticated(deviceId: current))
        state.devices = DevicesState(devices: [
            UserDevice(id: current, name: "iPhone 16 Pro", lastSeenAt: Date()),
            UserDevice(id: other, name: "iPhone 13", lastSeenAt: nil)
        ])
        return state
    }

    func testOpeningTheScreenDropsThePreviousList() {
        let state = appReducer(state: loadedState(), action: .devices(.load))

        XCTAssertEqual(state.devices?.devices, [])
        XCTAssertEqual(state.devices?.isLoading, true)
    }

    func testARevokedDeviceLeavesTheListAndTheInFlightSet() {
        var before = loadedState()
        before.devices?.revoking = [other]

        let state = appReducer(state: before, action: .devices(.revoked(deviceId: other)))

        XCTAssertEqual(state.devices?.devices.map(\.id), [current])
        XCTAssertTrue(state.devices?.revoking.isEmpty == true)
    }

    func testAFailedRevocationReleasesTheRow() {
        var before = loadedState()
        before.devices?.revoking = [other]

        let state = appReducer(state: before, action: .devices(.revokeFailed(deviceId: other)))

        XCTAssertEqual(state.devices?.devices.count, 2)
        XCTAssertTrue(state.devices?.revoking.isEmpty == true)
        XCTAssertEqual(state.devices?.failure, .revoke)
    }

    /// The screen is closed; the request it started is still out. Whatever comes back has nowhere
    /// to be shown, and must not build a state for nobody.
    func testAnswersThatLandAfterTheScreenClosedChangeNothing() {
        let closed = appReducer(state: loadedState(), action: .devices(.close))
        XCTAssertNil(closed.devices)

        let late: [DevicesAction] = [
            .setDevices([UserDevice(id: other, name: "iPhone 13", lastSeenAt: nil)]),
            .loadFailed,
            .revoked(deviceId: other),
            .revokeFailed(deviceId: other)
        ]

        for action in late {
            XCTAssertNil(appReducer(state: closed, action: .devices(action)).devices)
        }
    }

    /// Signing out takes the screen with it: the list belongs to the account that has gone, and a
    /// revocation in flight was asked for on its behalf.
    func testSigningOutClearsTheList() {
        let state = appReducer(state: loadedState(), action: .auth(.set(.notAuthenticated)))

        XCTAssertNil(state.devices)
    }
}
