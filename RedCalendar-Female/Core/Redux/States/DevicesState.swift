//
//  DevicesState.swift
//  RedCalendar-Female
//

/// The device list screen (SYNC.md §19), or `nil` in `AppState` while it is closed — the same
/// shape `emailBinding` has, and for the same reason: the list is server truth read for one
/// screen, and keeping it after the screen has gone would only mean showing it stale next time.
///
/// A struct rather than a state machine, unlike `EmailBindingState`: there are no steps here. A
/// list is loading or loaded, and a row is being revoked or it is not.
struct DevicesState: Equatable, Sendable {
    var devices: [UserDevice] = []
    var isLoading: Bool = false
    /// The ids with a revocation in flight. A set rather than a single id because the rows are
    /// independent: nothing stops a second swipe while the first request is out, and disabling
    /// the whole list to prevent that would be a worse answer than letting both run.
    var revoking: Set<String> = []
    var failure: Failure?

    /// Which request failed, not why. The person can do exactly one thing about either — try
    /// again — so the reason belongs in the log, where it can be read, rather than in a sentence
    /// on screen that offers no different action.
    enum Failure: Equatable, Sendable {
        case load
        case revoke

        var message: String {
            switch self {
            case .load: "Не удалось загрузить список устройств."
            case .revoke: "Не удалось отключить устройство. Попробуйте ещё раз."
            }
        }
    }
}
