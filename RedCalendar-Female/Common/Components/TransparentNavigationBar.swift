//
//  TransparentNavigationBar.swift
//  RedCalendar-Female
//

import SwiftUI
import UIKit

// Strips the navigation bar's own background so a screen can draw its own.
//
// The calendar needs this: its top band is what the grid dissolves into, and a bar drawing a
// material behind the title would sit on top of that band and hide it. From iOS 16 the
// intent has a name — `.toolbarBackground(.hidden, for: .navigationBar)`. Below it the only
// way in is UIKit, and `UINavigationBar.appearance()` is the wrong instrument: it is global,
// so it would also strip the background off the Settings and Statistics sheets, where the bar
// is the only thing separating a scrolling form from the title above it. So the bar is
// reached through the controller that actually owns it, and nothing else is touched.
struct TransparentNavigationBar: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        Controller()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class Controller: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            // It carries no content and is sized to nothing; it must never be in the way of a
            // touch that belongs to the calendar behind it.
            view.isUserInteractionEnabled = false
        }

        // Both hooks, because neither one alone is reliable: the controller can be added to
        // the hierarchy before it has a navigation controller, and it can be re-shown without
        // being moved again.
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyTransparentAppearance()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            applyTransparentAppearance()
        }

        private func applyTransparentAppearance() {
            guard let navigationBar = navigationController?.navigationBar else { return }

            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()

            navigationBar.standardAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
    }
}

extension View {
    /// Removes the navigation bar's background, for a screen that draws its own top treatment.
    @ViewBuilder
    func transparentNavigationBarBackground() -> some View {
        if #available(iOS 16.0, *) {
            toolbarBackground(.hidden, for: .navigationBar)
        } else {
            background(TransparentNavigationBar().frame(width: 0, height: 0))
        }
    }
}
