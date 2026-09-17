//
//  SourceStringCatalog.swift
//  RedCalendar-FemaleTests
//

import XCTest

/// `Localizable.xcstrings`'s `strings` object, read from the source tree rather than from a
/// bundle: `.xcstrings` is compiled into `.strings`/`.stringsdict` on the way into the app, and the
/// key list is what is being checked, not the lookup.
///
/// The source tree is only reachable where the tests run on the Mac that built them — a simulator
/// shares its file system, a device does not. There the check is skipped rather than failed: a
/// `try!` on the missing file crashed the test process, and Xcode reported that as the whole run
/// being cancelled, one test in. Nothing about the catalog differs between the two destinations.
func sourceStringCatalog() throws -> [String: [String: Any]] {
    // …/RedCalendar-FemaleTests/SourceStringCatalog.swift → …/RedCalendar-Female/Localizable.xcstrings
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("RedCalendar-Female/Localizable.xcstrings")
    try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path),
                      "The source tree is not reachable from this destination")
    let data = try Data(contentsOf: url)
    let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try XCTUnwrap(root["strings"] as? [String: [String: Any]])
}
