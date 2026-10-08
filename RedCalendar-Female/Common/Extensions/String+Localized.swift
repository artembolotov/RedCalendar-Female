//
//  String+Localized.swift
//  RedCalendar-Female
//

import Foundation

extension String {
    /// A catalog string with its arguments filled in.
    ///
    /// `Text("Some.Key \(value)")` does not do this: SwiftUI folds the interpolation into the key
    /// itself, so the catalog is asked for `Some.Key %@` rather than for `Some.Key`. A key with a
    /// placeholder glued to its end is still a key that works, but it is not a name — it changes
    /// shape when the sentence does, and the same string used with and without an argument becomes
    /// two entries. So a parameterised string is looked up by its bare key and formatted after.
    ///
    /// The format specifiers live in the translation, where a translator can move them: Russian
    /// and English do not put a name in the same place in a sentence.
    static func localized(_ key: String.LocalizationValue, _ arguments: any CVarArg...) -> String {
        String(format: String(localized: key), arguments: arguments)
    }
}
