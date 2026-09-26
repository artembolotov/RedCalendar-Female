//
//  UIApplication+Presentations.swift
//  RedCalendar-Female
//

import UIKit

extension UIApplication {
    /// Dismisses everything presented over the key window's root, then calls `completion` — at
    /// once when nothing is.
    ///
    /// For a route that has to reach the screen whatever is on it. SwiftUI replaces one of its own
    /// sheets with another by itself, but not a presentation it does not own: `ShareLink` has
    /// UIKit present the activity controller, a sheet asked for over that is refused, and the
    /// binding that asked stays set — `onAppear` of the sheet's content included — with nothing on
    /// screen. Only UIKit can see that presentation, so only UIKit can take it down.
    ///
    /// Everything SwiftUI presented goes down with it, and nothing of it comes back: SwiftUI resets
    /// the binding of each sheet dismissed this way before `completion` runs. Measured, not
    /// assumed — iOS 18.6 and 26.5, a `.sheet(item:)` and a sibling view's `.sheet(isPresented:)`.
    func dismissPresentedScreens(completion: @escaping @MainActor () -> Void) {
        let root = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        guard let root, root.presentedViewController != nil else {
            completion()
            return
        }
        root.dismiss(animated: true, completion: completion)
    }
}
