//
//  EmailBindingState.swift
//  RedCalendar-Female
//

/// The two-step screen of SYNC.md §18.12 — an address, then a code — driven exactly the way
/// `EmailAuthState` drives sign-in: the transient cases are what the middleware acts on, and
/// every answer comes back as another `.set`.
///
/// `nil` in `AppState.emailBinding` means the screen is closed. It is Redux state rather than
/// `@State` on the view for the reason everything else here is: the request is in flight across
/// a screen the person can leave, and a code confirmed while the sheet is being dismissed still
/// has to reach the sync run that fetches the new address.
enum EmailBindingState: Equatable, Sendable {
    case entry(email: String = "", error: EmailBindingError? = nil)
    case requesting(email: String)
    /// `isChange` is the server's answer, not this device's guess: it says whether the account
    /// had an address when the code was sent, which is what decides whether the old one is about
    /// to be warned (§18.2).
    case codeEntry(email: String, isChange: Bool, code: String? = nil, error: EmailBindingError? = nil)
    case confirming(email: String, code: String, isChange: Bool)
    /// The end of the flow. `previousNotified` mirrors the server's flag (§18.12) but the view
    /// does not show it: the entry step already said a letter with a revert button is on its way
    /// to the old address, before the button was pressed — nothing changes that fact by the time
    /// this state is reached, so there is nothing new to tell. `changed == false` is the branch
    /// where the address was already ours — a double tap, or `ALREADY_YOURS` from the first step,
    /// which never sends a code at all.
    case done(email: String, changed: Bool, previousNotified: Bool)
}
