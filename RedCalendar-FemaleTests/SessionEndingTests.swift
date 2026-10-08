//
//  SessionEndingTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// A sign-out and a deletion each end the session; whichever is asked for first is the one taken.
final class SessionEndingTests: XCTestCase {

    private let signedIn = AppState(authState: .authenticated(deviceId: "device-1"))

    func testASignOutIsRecordedUntilItEnds() {
        let signingOut = appReducer(state: signedIn, action: .auth(.logout))
        let signedOut = appReducer(state: signingOut, action: .auth(.set(.notAuthenticated)))

        XCTAssertEqual(signingOut.sessionEnding, .signOut)
        XCTAssertNil(signedOut.sessionEnding)
    }

    /// A deletion after a sign-out would go out under a revoked device id and never be recorded.
    func testADeletionDoesNotReplaceASignOut() {
        let signingOut = appReducer(state: signedIn, action: .auth(.logout))

        let state = appReducer(state: signingOut, action: .auth(.deleteAccount))

        XCTAssertEqual(state.sessionEnding, .signOut)
    }

    func testASignOutDoesNotReplaceADeletion() {
        let deleting = appReducer(state: signedIn, action: .auth(.deleteAccount))

        let state = appReducer(state: deleting, action: .auth(.logout))

        XCTAssertEqual(state.sessionEnding, .deletion)
    }
}
