//
//  NotificationTapRoutingTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// What a tapped notification's payload routes to.
///
/// `UNNotificationResponse` has no public initialiser, so `NotificationDelegate`'s own
/// `didReceive response:` cannot be driven from a test directly — these pin the pure half instead:
/// `NotificationTapTarget(userInfo:)`, which decides what a payload means, and
/// `NotificationDelegate.action(for:)`, which decides what to dispatch for it.
final class NotificationTapRoutingTests: XCTestCase {

    // MARK: - NotificationTapTarget

    func testAddEmailKeyResolvesToTheAddEmailReminderTarget() {
        XCTAssertEqual(NotificationTapTarget(userInfo: ["t": "add_email"]), .addEmailReminder)
    }

    /// A real APNs delivery hands `userInfo` values in as `NSString`, not native Swift `String` —
    /// `as? String` has to bridge that, not merely match a literal Swift string in a test.
    func testAnNSStringTValueResolvesTheSameWayALiteralStringDoes() {
        let userInfo: [AnyHashable: Any] = ["t": NSString(string: "add_email")]

        XCTAssertEqual(NotificationTapTarget(userInfo: userInfo), .addEmailReminder)
    }

    func testAMissingTKeyResolvesToNothing() {
        XCTAssertNil(NotificationTapTarget(userInfo: [:]))
        XCTAssertNil(NotificationTapTarget(userInfo: ["aps": ["alert": ["loc-key": "PeriodStart.today"]]]))
    }

    /// A cycle notification's own payload — `t: "period_start"`, `d: <daystamp>` — is not this
    /// server's engagement type and must not be mistaken for it, the way a `default` on the
    /// switch guarantees for any string that isn't `"add_email"` today or in the future.
    func testACycleNotificationsTypeResolvesToNothing() {
        XCTAssertNil(NotificationTapTarget(userInfo: ["t": "period_start", "d": 9000]))
        XCTAssertNil(NotificationTapTarget(userInfo: ["t": "ovulation", "d": 9000]))
    }

    func testANonStringTValueResolvesToNothing() {
        XCTAssertNil(NotificationTapTarget(userInfo: ["t": 42]))
    }

    // MARK: - NotificationDelegate.action(for:)

    func testAddEmailPayloadRoutesToOpeningTheEmailEntryScreen() {
        guard case .emailBinding(.set(.entry)) = NotificationDelegate.action(for: ["t": "add_email"]) else {
            return XCTFail("expected .emailBinding(.set(.entry)))")
        }
    }

    func testAnUnrecognisedPayloadRoutesToNothing() {
        XCTAssertNil(NotificationDelegate.action(for: ["t": "period_start", "d": 9000]))
        XCTAssertNil(NotificationDelegate.action(for: [:]))
    }

    // MARK: - What the reducer does with the routed action

    /// `appReducer` already refuses to reopen a screen the person closed (`(nil, _)` staying `nil`
    /// unless the incoming state is `.entry` — see `AppReducer`'s `.emailBinding` case) and this is
    /// the one shape a fresh tap ever produces, so it is always the transition allowed to start
    /// from a closed screen — independent of `authState`, since the tap can land before
    /// `AuthMiddleware.check` has resolved on a cold launch.
    func testTheRoutedActionOpensTheEmailEntryScreenFromAnyAuthState() {
        for authState: AuthState? in [nil, .notAuthenticated, .authenticated(deviceId: "device-1")] {
            let before = AppState(authState: authState)
            let action = NotificationDelegate.action(for: ["t": "add_email"])!

            let after = appReducer(state: before, action: action)

            XCTAssertEqual(after.emailBinding, .entry())
        }
    }

    /// A second tap while the screen is already mid-flow (a code already requested) must not
    /// stomp it back to a blank entry step — the same "closed screen only" rule above, from the
    /// other side: once `emailBinding` is non-nil, `(nil, _)` no longer applies and every `.set`
    /// is honoured, entry included, exactly as tapping "Email" again from `ProfileView` would be.
    func testARepeatedTapWhileAlreadyMidFlowRestartsAtEntry() {
        var before = AppState(authState: .authenticated(deviceId: "device-1"))
        before.emailBinding = .codeEntry(email: "a@example.com", isChange: false)

        let after = appReducer(state: before, action: NotificationDelegate.action(for: ["t": "add_email"])!)

        XCTAssertEqual(after.emailBinding, .entry())
    }
}
