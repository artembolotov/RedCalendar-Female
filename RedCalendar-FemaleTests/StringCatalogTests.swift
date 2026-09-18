//
//  StringCatalogTests.swift
//  RedCalendar-FemaleTests
//

import XCTest

/// An abstract key fails silently. `Text("Settings.Title")` with nothing behind it draws
/// `Settings.Title` on the screen — there is no crash, no warning, and no fallback to read, which
/// is what Russian-text-as-key used to give for free. So the three things that can go wrong are
/// checked here rather than left to be noticed:
///
/// 1. a key that does not follow the scheme (`Settings.title` in place of `Settings.Title` is a
///    second entry, not an error),
/// 2. a key the catalog has no string for in one of the two languages, and
/// 3. a key that is the text itself again — the shape the whole catalog was in before, and the
///    one a hurried `Text("Новая строка")` puts a corner of it back into.
///
/// The catalog is read from the source tree — see `sourceStringCatalog()` for why, and for why that
/// skips on a device.
final class StringCatalogTests: XCTestCase {

    /// `Scope.Path.Role`, PascalCase throughout, two to four segments.
    ///
    /// Computed rather than stored: a `static let` of a non-`Sendable` type is global mutable
    /// state under `SWIFT_VERSION = 6.0`.
    private static var schema: NSRegularExpression {
        try! NSRegularExpression(pattern: "^[A-Z][A-Za-z0-9]*(\\.[A-Z][A-Za-z0-9]*){1,3}$")
    }

    /// Every push notification's `loc-key`: the server names these (`notification-messages.js`)
    /// and iOS resolves them against the bundle, so they belong to the server's contract rather
    /// than to this scheme. `PeriodStart`/`PeriodEnd`/`Ovulation` are the scheduled cycle
    /// notifications and predate the scheme outright; `AddEmail` is the first engagement push
    /// (SYNC.md §20) and follows the same vocabulary shape deliberately — an unnamed key with no
    /// dot at all (`AddEmail`) beside the `.named` variant every scope here carries.
    private static let serverOwnedScopes = ["PeriodStart", "PeriodEnd", "Ovulation", "AddEmail"]

    // MARK: - Tests

    func testEveryKeyFollowsTheScheme() throws {
        let catalog = try sourceStringCatalog()
        let offenders = catalog.keys
            .filter { !Self.isServerOwned($0) }
            .filter { key in
                Self.schema.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) == nil
            }
        XCTAssertEqual(offenders.sorted(), [], "Keys outside Scope.Path.Role, PascalCase, 2–4 segments")
    }

    func testEveryKeyIsTranslatedIntoBothLanguages() throws {
        let catalog = try sourceStringCatalog()
        var offenders: [String] = []
        for (key, entry) in catalog {
            for language in ["en", "ru"] where !Self.hasString(entry, language) {
                offenders.append("\(key) [\(language)]")
            }
        }
        XCTAssertEqual(offenders.sorted(), [], "Keys with no string in one of the two languages")
    }

    func testNoKeyIsRussianTextAgain() throws {
        let catalog = try sourceStringCatalog()
        let offenders = catalog.keys.filter(Self.holdsRussianText)
        XCTAssertEqual(offenders.sorted(), [], "Give these a Scope.Path.Role name instead")
    }

    // MARK: - Private Methods

    private static func isServerOwned(_ key: String) -> Bool {
        // Equality too, not only the dot-prefixed form: `AddEmail`'s unnamed variant is the bare
        // scope name itself, unlike every cycle key, which always carries at least a `.today` /
        // `.before_N` / `.after_N` suffix.
        serverOwnedScopes.contains { key == $0 || key.hasPrefix($0 + ".") }
    }

    private static func holdsRussianText(_ key: String) -> Bool {
        key.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) }
    }

    /// True when the entry carries a non-empty string for the language, whether it is a plain unit
    /// or the plural variations `Common.Days` is built from.
    private static func hasString(_ entry: [String: Any], _ language: String) -> Bool {
        guard let localizations = entry["localizations"] as? [String: Any],
              let localization = localizations[language] as? [String: Any] else { return false }

        if let unit = localization["stringUnit"] as? [String: Any],
           let value = unit["value"] as? String {
            return !value.isEmpty
        }
        if let variations = localization["variations"] as? [String: Any],
           let plural = variations["plural"] as? [String: Any] {
            return !plural.isEmpty && plural.values.allSatisfy { form in
                guard let form = form as? [String: Any],
                      let unit = form["stringUnit"] as? [String: Any],
                      let value = unit["value"] as? String else { return false }
                return !value.isEmpty
            }
        }
        return false
    }
}
