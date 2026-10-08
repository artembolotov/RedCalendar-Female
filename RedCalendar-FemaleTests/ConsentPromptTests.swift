//
//  ConsentPromptTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// The prompt after sign-in (SYNC.md §21.5): which version it asks for, and when it goes away.
final class ConsentPromptTests: XCTestCase {

    private func promptedState(for version: Int, deviceId: String = "device-1") -> AppState {
        var state = AppState(authState: .authenticated(deviceId: deviceId))
        state.consent.required = version
        return state
    }

    /// The prompt for `version`, with the acceptance of it sent.
    private func sentState(for version: Int) -> AppState {
        appReducer(state: promptedState(for: version), action: .consent(.accept(version: version)))
    }

    private func attempt(_ version: Int, deviceId: String = "device-1") -> ConsentAttempt {
        ConsentAttempt(deviceId: deviceId, version: version)
    }

    /// Taken down at once, rather than one run later.
    func testAnAcceptedVersionTakesThePromptDown() {
        let state = appReducer(
            state: sentState(for: 1),
            action: .consent(.accepted(version: 1, attempt: attempt(1)))
        )

        XCTAssertNil(state.consent.required)
        XCTAssertEqual(state.consent.acceptance, .accepted(version: 1))
    }

    /// A run that was already under way when the acceptance landed still names the version; it must
    /// not put the prompt back up for the second before the next run says `null`.
    func testARunFromBeforeTheAcceptanceDoesNotBringThePromptBack() {
        let accepted = appReducer(
            state: sentState(for: 1),
            action: .consent(.accepted(version: 1, attempt: attempt(1)))
        )

        let state = appReducer(state: accepted, action: .consent(.setRequired(1)))

        XCTAssertNil(state.consent.required)
    }

    /// A run named a newer version while the older one was on its way, and the person agreed to
    /// that one too. The older answer lands late: it is not the answer being waited on, and the
    /// newer one still is.
    func testALateAnswerForAnOlderVersionIsDropped() {
        let raised = appReducer(state: sentState(for: 1), action: .consent(.setRequired(2)))
        let resent = appReducer(state: raised, action: .consent(.accept(version: 2)))

        let late = appReducer(state: resent, action: .consent(.accepted(version: 1, attempt: attempt(1))))

        XCTAssertEqual(late.consent, resent.consent)

        let answered = appReducer(state: late, action: .consent(.accepted(version: 2, attempt: attempt(2))))

        XCTAssertNil(answered.consent.required)
        XCTAssertEqual(answered.consent.acceptance, .accepted(version: 2))
    }

    /// A newer text came out while the person was reading: the prompt asks for that one instead.
    func testAnOutdatedRefusalAsksForTheNewerVersion() {
        let state = appReducer(
            state: sentState(for: 1),
            action: .consent(.acceptRefused(.outdated(version: 2), attempt: attempt(1)))
        )

        XCTAssertEqual(state.consent.required, 2)
        XCTAssertEqual(state.consent.acceptance, .refused(.outdated(version: 2)))
    }

    func testAnInvalidRefusalLeavesTheVersionAsked() {
        let state = appReducer(
            state: sentState(for: 1),
            action: .consent(.acceptRefused(.invalid(version: 1), attempt: attempt(1)))
        )

        XCTAssertEqual(state.consent.required, 1)
    }

    /// A run naming a different version is a fresh question; the old answer's failure is not shown
    /// against it. The same version again — every run repeats it — keeps what is on screen.
    func testANewVersionFromARunClearsTheLastAnswer() {
        var before = promptedState(for: 1)
        before.consent.acceptance = .failed

        let same = appReducer(state: before, action: .consent(.setRequired(1)))
        let newer = appReducer(state: before, action: .consent(.setRequired(2)))

        XCTAssertEqual(same.consent.acceptance, .failed)
        XCTAssertEqual(newer.consent.acceptance, .idle)
        XCTAssertEqual(newer.consent.required, 2)
    }

    /// The prompt is the previous account's question.
    func testSigningOutForgetsThePrompt() {
        let state = appReducer(state: promptedState(for: 1), action: .auth(.set(.notAuthenticated)))

        XCTAssertNil(state.consent.required)
    }

    /// An answer that lands after the sign-out belongs to the session that sent it — not to the
    /// signed-out state, and not to another account that has signed in and sent the same version
    /// since.
    func testAnAnswerAfterSigningOutIsDropped() {
        let signedOut = appReducer(state: sentState(for: 1), action: .auth(.set(.notAuthenticated)))
        let otherAccount = appReducer(
            state: promptedState(for: 1, deviceId: "device-2"),
            action: .consent(.accept(version: 1))
        )

        for before in [signedOut, otherAccount] {
            for answer: ConsentAction in [
                .accepted(version: 1, attempt: attempt(1)),
                .acceptRefused(.outdated(version: 2), attempt: attempt(1)),
                .acceptFailed(attempt: attempt(1)),
            ] {
                let state = appReducer(state: before, action: .consent(answer))

                XCTAssertEqual(state.consent, before.consent)
            }
        }
    }

    /// Nothing can send it, so nothing would ever answer it.
    func testAnAcceptanceWithoutASessionIsNotMarkedSent() {
        let state = appReducer(state: AppState(authState: .notAuthenticated), action: .consent(.accept(version: 1)))

        XCTAssertEqual(state.consent.acceptance, .idle)
    }
}
