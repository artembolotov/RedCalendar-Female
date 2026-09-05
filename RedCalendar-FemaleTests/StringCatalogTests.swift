//
//  StringCatalogTests.swift
//  RedCalendar-FemaleTests
//

import XCTest

/// An abstract key fails silently. `Text("Settings.Title")` with nothing behind it draws
/// `Settings.Title` on the screen — there is no crash, no warning, and no fallback to read, which
/// is what Russian-text-as-key used to give for free. So the two things that can go wrong are
/// checked here rather than left to be noticed:
///
/// 1. a key that does not follow the scheme (`Settings.title` in place of `Settings.Title` is a
///    second entry, not an error), and
/// 2. a key the catalog has no string for in one of the two languages.
///
/// The catalog is read from the source tree rather than from a bundle: `.xcstrings` is compiled
/// into `.strings`/`.stringsdict` on the way into the app, and the key list is what is being
/// checked, not the lookup.
final class StringCatalogTests: XCTestCase {

    /// `Scope.Path.Role`, PascalCase throughout, two to four segments.
    ///
    /// Computed rather than stored: a `static let` of a non-`Sendable` type is global mutable
    /// state under `SWIFT_VERSION = 6.0`, and the same goes for `catalog` below.
    private static var schema: NSRegularExpression {
        try! NSRegularExpression(pattern: "^[A-Z][A-Za-z0-9]*(\\.[A-Z][A-Za-z0-9]*){1,3}$")
    }

    /// The scheduled cycle notifications: the server names these in the push payload's `loc-key`
    /// and iOS resolves them against the bundle, so they belong to the server's contract and to
    /// every build already in the wild. They cannot be renamed from here, and they predate the
    /// scheme.
    private static let serverOwnedScopes = ["PeriodStart", "PeriodEnd", "Ovulation"]

    /// Keys still holding their English text, waiting on the `Developer`, `Settings` and
    /// `PhoneCode` scopes. Delete each as its screen migrates; the last one out empties the list.
    private static let pendingLatinKeys: Set<String> = [
        "AppMetrica", "Developer", "Device ID", "Email", "Today Daystamp", "User ID",
    ]

    /// Keys still holding their Russian text. They are self-describing in Russian and fall back to
    /// themselves everywhere else, which is what the migration is replacing — until then they are
    /// exempt from both checks below. The count is asserted rather than the list, so a screen that
    /// migrates lowers it and a new Russian literal cannot quietly take the freed slot.
    private static let pendingRussianKeyCount = 69

    // MARK: - Tests

    func testEveryKeyFollowsTheScheme() {
        var offenders: [String] = []
        for key in Self.catalog.keys where !Self.isPending(key) && !Self.isServerOwned(key) {
            let range = NSRange(key.startIndex..., in: key)
            if Self.schema.firstMatch(in: key, range: range) == nil {
                offenders.append(key)
            }
        }
        XCTAssertEqual(offenders.sorted(), [], "Keys outside Scope.Path.Role, PascalCase, 2–4 segments")
    }

    func testEveryKeyIsTranslatedIntoBothLanguages() {
        var offenders: [String] = []
        for (key, entry) in Self.catalog where !Self.isPending(key) {
            for language in ["en", "ru"] where !Self.hasString(entry, language) {
                offenders.append("\(key) [\(language)]")
            }
        }
        XCTAssertEqual(offenders.sorted(), [], "Keys with no string in one of the two languages")
    }

    func testTheRussianKeysAreOnlyEverBeingRemoved() {
        let remaining = Self.catalog.keys.filter(Self.holdsRussianText).count
        XCTAssertLessThanOrEqual(
            remaining, Self.pendingRussianKeyCount,
            "A new Russian-text key was added. Give it a Scope.Path.Role name instead."
        )
        XCTAssertEqual(
            remaining, Self.pendingRussianKeyCount,
            "Russian keys were migrated — lower `pendingRussianKeyCount` to \(remaining)."
        )
    }

    func testThePendingListsDoNotRot() {
        let keys = Set(Self.catalog.keys)
        XCTAssertEqual(
            Self.pendingLatinKeys.subtracting(keys), [],
            "Listed as pending but no longer in the catalog — drop them from `pendingLatinKeys`."
        )
    }

    // MARK: - Catalog

    private static var catalog: [String: [String: Any]] {
        // …/RedCalendar-FemaleTests/StringCatalogTests.swift → …/RedCalendar-Female/Localizable.xcstrings
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("RedCalendar-Female/Localizable.xcstrings")
        let data = try! Data(contentsOf: url)
        let root = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        return root["strings"] as! [String: [String: Any]]
    }

    private static func isServerOwned(_ key: String) -> Bool {
        serverOwnedScopes.contains { key.hasPrefix($0 + ".") }
    }

    private static func holdsRussianText(_ key: String) -> Bool {
        key.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) }
    }

    private static func isPending(_ key: String) -> Bool {
        holdsRussianText(key) || pendingLatinKeys.contains(key)
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
