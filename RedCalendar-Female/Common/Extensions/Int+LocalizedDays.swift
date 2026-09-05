//
//  Int+LocalizedDays.swift
//  RedCalendar-Female
//

import Foundation

extension Int {
    /// «1 день» / «2 дня» / «5 дней», "1 day" / "2 days" — the day count read out loud rather than
    /// shown as a bare number. Shared by `ProfileView`, `CycleOnboardingView`, `DeleteAccountSheet`
    /// and `EmailBindingView`.
    ///
    /// The rule lives in the catalog's plural variations, not in a `switch` here. Russian's
    /// one/few/many split and English's one/other are two of many, and a hand-written rule can
    /// only ever be right about the language it was written for — this one was, and «5 days» would
    /// have been its first casualty.
    ///
    /// `localizedStringWithFormat` rather than `String(localized:)`: the variant is chosen from
    /// the argument, so the count has to reach the lookup rather than be interpolated after it.
    var localizedDays: String {
        String.localizedStringWithFormat(
            NSLocalizedString("Common.Days", comment: "A number of days, read out loud"),
            self
        )
    }
}
