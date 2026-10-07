//
//  ConsentRefusalTests.swift
//  RedCalendar-FemaleTests
//

import XCTest
@testable import RedCalendar_Female

/// The consent refusals of SYNC.md §21.3, read from the envelopes the server actually sends.
///
/// `409 CONSENT_OUTDATED` cannot be drawn from the production server while the current version is
/// 1 — the only version below it is 0, which is refused as invalid — so this is the one place it
/// is exercised at all.
final class ConsentRefusalTests: XCTestCase {

    // MARK: - ConsentRefusal

    func testAnOutdatedRefusalCarriesTheCurrentVersion() throws {
        let error = try refusal("""
            {"success": false, "error": "CONSENT_OUTDATED", "message": "…", "data": {"version": 2}, "timestamp": "2026-10-07T00:00:00.000Z"}
            """)

        XCTAssertEqual(ConsentRefusal(error), .outdated(version: 2))
    }

    func testAnInvalidRefusalCarriesTheCurrentVersion() throws {
        let error = try refusal("""
            {"success": false, "error": "INVALID_CONSENT_VERSION", "message": "…", "data": {"version": 1}, "timestamp": "2026-10-07T00:00:00.000Z"}
            """)

        XCTAssertEqual(ConsentRefusal(error), .invalid(version: 1))
    }

    /// Without the version there is nothing to send back, so it is not acted on as outdated.
    func testAnOutdatedRefusalWithoutAVersionIsNotRecognised() throws {
        let error = try refusal("""
            {"success": false, "error": "CONSENT_OUTDATED", "message": "…", "timestamp": "2026-10-07T00:00:00.000Z"}
            """)

        XCTAssertNil(ConsentRefusal(error))
    }

    func testOtherRefusalsAreNotConsentRefusals() throws {
        let error = try refusal("""
            {"success": false, "error": "INVALID_CODE", "message": "…", "data": {"requestId": "r", "remainingAttempts": 2}, "timestamp": "2026-10-07T00:00:00.000Z"}
            """)

        XCTAssertNil(ConsentRefusal(error))
        XCTAssertNil(ConsentRefusal(APIServiceError.unauthorized))
        XCTAssertNil(ConsentRefusal(APIServiceError.httpError(409)))
    }

    // MARK: - APIError

    /// A `data` of another shape costs only the version — never the refusal around it, which
    /// `validateHTTPResponse` decodes with `try?` and would otherwise flatten to a bare status.
    func testADataOfAnotherShapeStillDecodesTheRefusal() throws {
        let apiError = try decode("""
            {"success": false, "error": "SOMETHING", "message": "text", "data": "not an object", "timestamp": "2026-10-07T00:00:00.000Z"}
            """)

        XCTAssertEqual(apiError.error, "SOMETHING")
        XCTAssertEqual(apiError.displayMessage, "text")
        XCTAssertNil(apiError.data?.version)
    }

    // MARK: - SyncResponse

    func testConsentRequiredIsReadFromASyncResponse() throws {
        XCTAssertEqual(try syncResponse(#""consent_required": 1"#).consentRequired, 1)
        XCTAssertNil(try syncResponse(#""consent_required": null"#).consentRequired)
        XCTAssertNil(try syncResponse(nil).consentRequired)
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> APIError {
        try JSONDecoder().decode(APIError.self, from: Data(json.utf8))
    }

    private func refusal(_ json: String) throws -> APIServiceError {
        let apiError = try decode(json)
        return .refused(apiError)
    }

    private func syncResponse(_ field: String?) throws -> SyncResponse {
        let extra = field.map { ", \($0)" } ?? ""
        let json = #"{"next_cursor": 5, "has_more": false"# + extra + "}"
        return try JSONDecoder().decode(SyncResponse.self, from: Data(json.utf8))
    }
}
