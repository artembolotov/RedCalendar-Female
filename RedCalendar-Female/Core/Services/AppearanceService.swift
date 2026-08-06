//
//  AppearanceService.swift
//  RedCalendar-Female
//

import Foundation

// A setter rather than a settable property: `@Injected` hands back a protocol existential, and
// assigning through one would require the protocol to be class-constrained for no gain.
protocol AppearanceServiceProtocol: Sendable {
    var accentTheme: AccentTheme { get }
    func setAccentTheme(_ theme: AccentTheme)
}

final class AppearanceService: AppearanceServiceProtocol, Sendable {
    // UserDefaults isn't Sendable-audited, but every access it documents is thread-safe by
    // design — the property itself just needs to say so.
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
