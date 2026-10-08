//
//  SupportEmailText.swift
//  RedCalendar-Female
//

import SwiftUI

/// A catalog string with the support address in place of its `%@`, drawn as a link that opens mail.
///
/// The address is not translated, so it lives in `Constants` rather than in every translation, and
/// the link is put together here rather than written as Markdown in the catalog: nothing in the
/// address is ever read as markup, and there is no parse to fail.
///
/// The link targets the token `email`, opened by this view, rather than a `mailto:` URL — a
/// `mailto:` link breaks across lines wrongly on older iOS versions.
struct SupportEmailText: View {
    private let key: String.LocalizationValue

    init(_ key: String.LocalizationValue) {
        self.key = key
    }

    var body: some View {
        Text(text)
            .environment(\.openURL, OpenURLAction { url in
                if url.absoluteString == "email" {
                    UIApplication.shared.open(Constants.URLs.supportMail)
                }
                return .handled
            })
    }

    // MARK: - Private Methods

    private var text: AttributedString {
        var address = AttributedString(Constants.URLs.supportEmail)
        address.link = URL(string: "email")

        let parts = String(localized: key).components(separatedBy: "%@")
        return parts.dropFirst().reduce(AttributedString(parts[0])) { $0 + address + AttributedString($1) }
    }
}
