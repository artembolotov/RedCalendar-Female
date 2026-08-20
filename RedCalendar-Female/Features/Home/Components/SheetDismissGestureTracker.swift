//
//  SheetDismissGestureTracker.swift
//  RedCalendar-Female
//

import SwiftUI

// The first attempt here was pure SwiftUI: `.simultaneousGesture(DragGesture(minimumDistance:
// 0))` on the sheet's root. It broke on contact — SwiftUI's own drag recognizer, even declared
// "simultaneous", still competed for the touch stream in a way neither the system's interactive
// sheet-dismiss recognizer nor a `Button`'s own tap recognizer tolerated from a sibling that
// isn't a scroll view: the sheet stopped swiping closed, and the close button stopped
// registering taps at all.
//
// This tracks the same drag the way `WindowGestureHandler` already tracks the day card's: a raw
// `UIPanGestureRecognizer` attached directly to the window. A recognizer on an ancestor sees
// every touch in the sheet's hierarchy regardless of which specific button or text field was
// hit underneath it, which a view placed as a SwiftUI sibling cannot — UIKit only offers a touch
// to gesture recognizers along the hit-tested view's own ancestor chain. `cancelsTouchesInView =
// false` and an unconditional `shouldRecognizeSimultaneouslyWith` make it a pure observer: unlike
// `WindowGestureHandler`, which is deliberately exclusive, this one never claims a touch, so the
// system's own dismiss recognizer and everything on the sheet keep working exactly as they did
// before this existed.
struct SheetDismissGestureTracker: UIViewRepresentable {
    let onTranslationChange: (CGFloat, UIGestureRecognizer.State) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        setupGestureIfPossible(view: view, context: context)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTranslationChange = onTranslationChange

        if context.coordinator.gesture == nil {
            setupGestureIfPossible(view: uiView, context: context)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cleanUp()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTranslationChange: onTranslationChange)
    }

    private func findWindow(from view: UIView) -> UIWindow? {
        view.window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })
    }

    // The view isn't attached to a window yet at `makeUIView` time, so this is also called
    // again from `updateUIView` once SwiftUI has mounted it — the same two-attempt shape
    // `WindowGestureHandler` uses for the same reason.
    private func setupGestureIfPossible(view: UIView, context: Context) {
        guard let window = findWindow(from: view) else { return }

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        pan.name = "SheetKeyboardDuckTracker"

        window.addGestureRecognizer(pan)
        context.coordinator.gesture = pan
        context.coordinator.onTranslationChange = onTranslationChange
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTranslationChange: (CGFloat, UIGestureRecognizer.State) -> Void
        weak var gesture: UIPanGestureRecognizer?

        init(onTranslationChange: @escaping (CGFloat, UIGestureRecognizer.State) -> Void) {
            self.onTranslationChange = onTranslationChange
        }

        func cleanUp() {
            if let gesture, let view = gesture.view {
                view.removeGestureRecognizer(gesture)
            }
            gesture = nil
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            onTranslationChange(gesture.translation(in: gesture.view).y, gesture.state)
        }

        // Never claims exclusivity — this is a pure observer, alongside whatever else is
        // already recognizing: the system's sheet-dismiss pan, a Button's tap, a TextEditor's
        // own scroll pan.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
