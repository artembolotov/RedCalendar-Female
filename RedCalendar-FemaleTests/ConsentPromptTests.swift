//
//  ConsentPromptTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// The prompt after sign-in (SYNC.md §21.5): which version it asks for, and when it goes away.
final class ConsentPromptTests: XCTestCase {

    private func promptedState(for version: Int) -> AppState {
        var state = AppState(authState: .authenticated(deviceId: "device-1"))
        state.consent.required = version
        return state
    }

    /// Taken down at once, rather than one run later.
    func testAnAcceptedVersionTakesThePromptDown() {
        let state = appReducer(state: promptedState(for: 1), action: .consent(.accepted(version: 1)))

        XCTAssertNil(state.consent.required)
        XCTAssertEqual(state.consent.acceptance, .accepted(version: 1))
    }

    /// A run that was already under way when the acceptance landed still names the version; it must
    /// not put the prompt back up for the second before the next run says `null`.
    func testARunFromBeforeTheAcceptanceDoesNotBringThePromptBack() {
        let accepted = appReducer(state: promptedState(for: 1), action: .consent(.accepted(version: 1)))

        let state = appReducer(state: accepted, action: .consent(.setRequired(1)))

        XCTAssertNil(state.consent.required)
    }

    /// An acceptance that lands after a run already asked for a newer version leaves that question
    /// standing.
    func testAcceptingAnotherVersionLeavesThePrompt() {
        let state = appReducer(state: promptedState(for: 2), action: .consent(.accepted(version: 1)))

        XCTAssertEqual(state.consent.required, 2)
    }

    /// A newer text came out while the person was reading: the prompt asks for that one instead.
    func testAnOutdatedRefusalAsksForTheNewerVersion() {
        let state = appReducer(
            state: promptedState(for: 1),
            action: .consent(.acceptRefused(.outdated(version: 2)))
        )

        XCTAssertEqual(state.consent.required, 2)
        XCTAssertEqual(state.consent.acceptance, .refused(.outdated(version: 2)))
    }

    func testAnInvalidRefusalLeavesTheVersionAsked() {
        let state = appReducer(
            state: promptedState(for: 1),
            action: .consent(.acceptRefused(.invalid(version: 1)))
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

    /// An answer that lands after the sign-out belongs to the session that sent it, not to the
    /// next one.
    func testAnAnswerAfterSigningOutIsDropped() {
        let signedOut = appReducer(state: promptedState(for: 1), action: .auth(.set(.notAuthenticated)))

        for answer: ConsentAction in [
            .accepted(version: 1),
            .acceptRefused(.outdated(version: 2)),
            .acceptFailed,
        ] {
            let state = appReducer(state: signedOut, action: .consent(answer))

            XCTAssertEqual(state.consent, signedOut.consent)
        }
    }
}
