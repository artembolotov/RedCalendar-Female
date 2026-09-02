//
//  CycleOnboardingCommitTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// What these pin is an ordering, and the reason it needs pinning is that nothing about the code
/// looks order-dependent: four `store.send` calls, three of them writes to the same row.
///
/// Each write comes back as its own profile observation, and `.completedRegistrationOnboarding`
/// has already cleared `isFreshRegistration` — the guard holding the system permission alert off
/// — by the time the first delivery lands, because the reducer runs synchronously and the
/// observation does not. A delivery carrying the cycle numbers and no `notifications` key reads
/// as `NotificationPreference.enabled`, by the rule that silence means on, which is enough to put
/// the alert on screen. In the original order that is exactly what happened: verified on device,
/// a registration finished with the switch *off* was asked for permission anyway, off the
/// cycle-length delivery, two deliveries before its own answer arrived.
///
/// So the switch must be written first. An alert iOS only allows once per install is the cost of
/// getting this wrong, and it is invisible in every path except a brand-new registration whose
/// author turned notifications down.
final class CycleOnboardingCommitTests: XCTestCase {

    private func actions(notificationsEnabled: Bool = true) -> [AppAction] {
        CycleOnboardingCommit.actions(
            cycleLength: 30,
            periodLength: 4,
            notificationsEnabled: notificationsEnabled
        )
    }

    /// The whole point of the type. Not "the switch is somewhere before the numbers" — first,
    /// because a write inserted ahead of it later would be a delivery without the answer in it.
    func testTheNotificationsSwitchIsWrittenFirst() {
        guard case .data(.setNotificationsEnabled(let enabled))? = actions(notificationsEnabled: false).first else {
            return XCTFail("The first action must be the notifications switch")
        }
        XCTAssertFalse(enabled)
    }

    /// The flag that holds the alert off is cleared by this one, so it has to come after every
    /// write whose delivery would otherwise be judged without an answer in it.
    func testTheOnboardingFlagIsClearedLast() {
        guard case .auth(.completedRegistrationOnboarding)? = actions().last else {
            return XCTFail("The last action must clear the onboarding flag")
        }
    }

    /// Both numbers are written whatever the steppers were left at: there is no stored value here
    /// for "unchanged" to mean anything against, and tapping through with the defaults is the
    /// answer being given.
    func testBothCycleNumbersAreWrittenBetweenTheTwo() {
        let middle = actions().dropFirst().dropLast()
        XCTAssertEqual(middle.count, 2)

        guard case .data(.setCycleLength(let cycleLength)) = middle.first,
              case .data(.setPeriodLength(let periodLength)) = middle.last else {
            return XCTFail("The two cycle numbers must sit between the switch and the flag")
        }
        XCTAssertEqual(cycleLength, 30)
        XCTAssertEqual(periodLength, 4)
    }

    /// The switch is the answer given, not a fixed value: the enabled case is the one that has to
    /// reach the middleware as `.enabled` for the alert to appear at all.
    func testTheSwitchCarriesTheChosenValue() {
        guard case .data(.setNotificationsEnabled(let enabled))? = actions(notificationsEnabled: true).first else {
            return XCTFail("The first action must be the notifications switch")
        }
        XCTAssertTrue(enabled)
    }
}
