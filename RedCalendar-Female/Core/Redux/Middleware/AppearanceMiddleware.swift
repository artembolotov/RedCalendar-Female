//
//  AppearanceMiddleware.swift
//  RedCalendar-Female
//

import UIKit

// MARK: - Appearance Middleware
let appearanceMiddleware: Middleware = { state, action, dispatch in
    @Injected var appearance: AppearanceServiceProtocol

    guard case .appearance(let appearanceAction) = action else { return }

    switch appearanceAction {

    case .checkAccentTheme:
        dispatch(.appearance(.setAccentTheme(appearance.accentTheme)))

    case .setAccentTheme(let theme):
        // The reducer has already put the theme in state; writing it to disk is the side
        // effect, which is why this runs on the same action rather than a separate one.
        appearance.setAccentTheme(theme)
        applyAccentTint(theme)
    }

}

/// UIKit's own tint, which the app's single SwiftUI `.tint` does not reach.
///
/// It exists for the handful of surfaces that are not SwiftUI: the caret and selection handles in
/// `PhoneNumberKitField`'s `UITextField`, and anything UIKit puts on screen on the app's behalf.
/// They read `UIWindow.tintColor`, and nothing about SwiftUI's `.tint` modifier reaches down into
/// a `UIViewRepresentable`.
///
/// This used to be one line in `AppDelegate` — `UIWindow.appearance().tintColor` set to the
/// `AccentColor` asset at launch — and it was wrong in the way an appearance proxy usually is: it
/// hardcoded coral no matter which of the three themes the user had chosen, before
/// `.checkAccentTheme` had even read the stored one, and an appearance proxy is consulted when a
/// window is *created*, so choosing a different accent in settings could never change it.
///
/// Driving it from `.setAccentTheme` fixes both halves at once: that action carries the stored
/// theme on launch and the chosen one afterwards, so this runs exactly when the answer changes.
/// Both the proxy and the live windows are written — the proxy for any window built later, the
/// windows for the one already on screen, which has long since read the proxy.
@MainActor
private func applyAccentTint(_ theme: AccentTheme) {
    guard let accent = UIColor(named: theme.accentAssetName) else { return }

    UIWindow.appearance().tintColor = accent

    for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        for window in windowScene.windows {
            window.tintColor = accent
        }
    }
}
