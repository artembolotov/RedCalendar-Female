//
//  SignInConsentTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// The consent step in front of every sign-in (SYNC.md §21.4): what the reducer keeps between the
/// step and the request that carries its version, and how a refusal of that version reads.
final class SignInConsentTests: XCTestCase {

    private let verifying = AuthState.authenticating(.email(.verifying(email: "a@b.c", code: "123456")))

    // MARK: - Reducer

    func testAgreeingSetsTheVersionAndDropsTheRetry() {
        var before = AppState(authState: verifying)
        before.consent.signInRetry = verifying

        let state = appReducer(state: before, action: .consent(.agreeForSignIn(version: 3)))

        XCTAssertEqual(state.consent.signInVersion, 3)
        XCTAssertNil(state.consent.signInRetry)
    }

    /// The step comes back with the version the refusal named — no request needed to show it — and
    /// the request it turned back is kept whole, code included, to be sent again.
    func testAnOutdatedVersionAsksAgainAndKeepsTheRequest() {
        var before = AppState(authState: verifying)
        before.consent.signInVersion = 1
        before.consent.current = .loaded(version: 1)

        let state = appReducer(state: before, action: .consent(.signInConsentOutdated(version: 2, retry: verifying)))

        XCTAssertNil(state.consent.signInVersion)
        XCTAssertEqual(state.consent.current, .loaded(version: 2))
        XCTAssertEqual(state.consent.signInRetry, verifying)
    }

    /// Dropped and forgotten, so the step reads the current version afresh when it appears.
    func testADiscardedVersionIsReadAgain() {
        var before = AppState(authState: .migrating(userId: "legacy-firebase-uid"))
        before.consent.signInVersion = 1
        before.consent.current = .loaded(version: 1)

        let state = appReducer(state: before, action: .consent(.discardSignInConsent))

        XCTAssertNil(state.consent.signInVersion)
        XCTAssertEqual(state.consent.current, .idle)
    }

    /// Kept through sign-in, so the sheet sliding away does not draw the step again over itself.
    func testSigningInKeepsTheVersion() {
        var before = AppState(authState: verifying)
        before.consent.signInVersion = 1

        let state = appReducer(state: before, action: .auth(.set(.authenticated(deviceId: "device-1"))))

        XCTAssertEqual(state.consent.signInVersion, 1)
    }

    /// Cancelling the sheet and signing out both land here; the next sign-in asks again.
    func testSigningOutForgetsTheVersion() {
        var before = AppState(authState: verifying)
        before.consent.signInVersion = 1
        before.consent.signInRetry = verifying

        let state = appReducer(state: before, action: .auth(.set(.notAuthenticated)))

        XCTAssertNil(state.consent.signInVersion)
        XCTAssertNil(state.consent.signInRetry)
    }

    // MARK: - AuthenticationError

    /// The server's text names a request field; the person is shown something they can read.
    func testConsentRefusalsReadAsAConsentError() throws {
        let invalid = try refusal(#"{"error": "INVALID_CONSENT_VERSION", "message": "consent_version is required", "data": {"version": 1}, "timestamp": "t"}"#)
        let outdated = try refusal(#"{"error": "CONSENT_OUTDATED", "message": "…", "data": {"version": 2}, "timestamp": "t"}"#)

        XCTAssertEqual(AuthenticationError.from(invalid), .consentInvalid)
        XCTAssertEqual(AuthenticationError.from(outdated), .consentInvalid)
    }

    func testOtherRefusalsKeepTheServersMessage() throws {
        let error = try refusal(#"{"error": "INVALID_CODE", "message": "Wrong code", "timestamp": "t"}"#)

        XCTAssertEqual(AuthenticationError.from(error), .serverError("Wrong code"))
    }

    // MARK: - Helpers

    private func refusal(_ json: String) throws -> APIServiceError {
        let apiError = try JSONDecoder().decode(APIError.self, from: Data(json.utf8))
        return .refused(apiError)
    }
}
