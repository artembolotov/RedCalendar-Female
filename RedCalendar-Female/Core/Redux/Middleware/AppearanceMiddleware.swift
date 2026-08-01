//
//  AppearanceMiddleware.swift
//  RedCalendar-Female
//

// MARK: - Appearance Middleware
let appearanceMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var appearance: AppearanceServiceProtocol

    switch action {

    case .checkAccentTheme:
        return [.setAccentTheme(appearance.accentTheme)]

    case .setAccentTheme(let theme):
        // The reducer has already put the theme in state; writing it to disk is the side
        // effect, which is why this runs on the same action rather than a separate one.
        appearance.setAccentTheme(theme)

    default:
        break
    }

    return []
}
