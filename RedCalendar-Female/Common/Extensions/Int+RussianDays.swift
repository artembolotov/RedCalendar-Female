//
//  Int+RussianDays.swift
//  RedCalendar-Female
//

extension Int {
    /// «1 день», «2 дня», «5 дней» — the ordinary Russian plural rule, including the exception
    /// that 11 through 14 take the plural whatever their last digit is. Shared by `SettingsView`
    /// and `CycleOnboardingView`, the two places a day count is read out loud rather than shown
    /// as a bare number.
    var russianDays: String {
        let word: String
        switch (self % 100, self % 10) {
        case (11...14, _): word = "дней"
        case (_, 1):       word = "день"
        case (_, 2...4):   word = "дня"
        default:           word = "дней"
        }
        return "\(self) \(word)"
    }
}
