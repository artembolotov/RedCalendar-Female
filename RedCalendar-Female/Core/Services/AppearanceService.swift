//
//  AppearanceService.swift
//  RedCalendar-Female
//

import Foundation

// A setter rather than a settable property: `@Injected` hands back a protocol existential, and
// assigning through one would require the protocol to be class-constrained for no gain.
nonisolated protocol AppearanceServiceProtocol: Sendable {
    var accentTheme: AccentTheme { get }
    func setAccentTheme(_ theme: AccentTheme)
}

nonisolated final class AppearanceService: AppearanceServiceProtocol {
    // `UserDefaults` predates `Sendable` and never got the annotation, but it is documented as
    // thread-safe and this holds one to read a single key. Injectable, so tests can hand it a
    // suite of their own, which is the only reason it is stored rather than `.standard` inline.
    nonisolated(unsafe) private let defaults: UserDefaults
    private let accentThemeKey = "accentTheme"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // An unset key and a value written by a future version that dropped this case both land on
    // the fallback, so a bad read can never leave the app without an accent.
    var accentTheme: AccentTheme {
        guard let raw = defaults.string(forKey: accentThemeKey),
              let theme = AccentTheme(rawValue: raw) else {
            return .fallback
        }
        return theme
    }

    func setAccentTheme(_ theme: AccentTheme) {
        defaults.set(theme.rawValue, forKey: accentThemeKey)
    }
}
