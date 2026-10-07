//
//  AccountDeletedRefusalTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// `410 ACCOUNT_DELETED` (SYNC.md §17.5), read from the envelopes `check-phone`,
/// `verify-flash-call` and `migrate` actually send, and how the sign-in paths take it.
final class AccountDeletedRefusalTests: XCTestCase {

    // MARK: - AccountDeletedRefusal

    /// `check-phone` alone carries a `data` object with it, of a shape no other refusal has.
    func testTheCheckPhoneRefusalIsRecognised() throws {
        let error = try refusal("""
            {"success": false, "error": "ACCOUNT_DELETED", "message": "Этот аккаунт удалён.", "data": {"phone": "+79991234567", "exists": false}, "timestamp": "2026-10-07T00:00:00.000Z"}
            """)

        XCTAssertEqual(AccountDeletedRefusal(error)?.message, "Этот аккаунт удалён.")
    }

    func testTheVerifyAndMigrateRefusalIsRecognised() throws {
        let error = try refusal("""
            {"success": false, "error": "ACCOUNT_DELETED", "message": "This account has been deleted.", "timestamp": "2026-10-07T00:00:00.000Z"}
            """)

        XCTAssertEqual(AccountDeletedRefusal(error)?.message, "This account has been deleted.")
    }

    /// The migration checks for it before the consent refusals; the two must never both match.
    func testItIsNotAConsentRefusal() throws {
        let error = try refusal("""
            {"success": false, "error": "ACCOUNT_DELETED", "message": "…", "timestamp": "2026-10-07T00:00:00.000Z"}
            """)

        XCTAssertNil(ConsentRefusal(error))
    }

    func testOtherErrorsAreNotRecognised() throws {
        let error = try refusal("""
            {"success": false, "error": "INVALID_CODE", "message": "…", "timestamp": "2026-10-07T00:00:00.000Z"}
            """)

        XCTAssertNil(AccountDeletedRefusal(error))
        XCTAssertNil(AccountDeletedRefusal(APIServiceError.httpError(410)))
        XCTAssertNil(AccountDeletedRefusal(APIServiceError.serverError("ACCOUNT_DELETED")))
    }

    // MARK: - Sign-in errors

    /// Its own case, so the phone sign-in can leave the code screen for it.
    func testThePhoneSignInReadsItAsADeletedAccount() throws {
        let error = try refusal(#"{"error": "ACCOUNT_DELETED", "message": "Deleted", "timestamp": "t"}"#)

        XCTAssertEqual(AuthenticationError.from(error), .accountDeleted("Deleted"))
        XCTAssertEqual(AuthenticationError.accountDeleted("Deleted").localizedDescription, "Deleted")
    }

    /// The server's text is shown as it came, not re-keyed on the client.
    func testTheMigrationShowsTheServersText() {
        XCTAssertEqual(MigrationError.accountDeleted("Deleted").localizedDescription, "Deleted")
    }

    // MARK: - Helpers

    private func refusal(_ json: String) throws -> APIServiceError {
        let apiError = try JSONDecoder().decode(APIError.self, from: Data(json.utf8))
        return .refused(apiError)
    }
}
