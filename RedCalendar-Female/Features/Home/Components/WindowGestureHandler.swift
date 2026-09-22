//
//  WindowGestureHandler.swift
//  RedCalendar-Female
//

import SwiftUI

enum PanGestureState {
    case began, changed, ended, cancelled, failed
}

enum PanGestureAxis {
    case vertical, horizontal
}

// A pan recognizer attached to the key window rather than to a SwiftUI view: the day card
// has to answer drags that start anywhere over it, including on top of its buttons and rows,
// which would otherwise swallow the touch. The axis is decided once per gesture, so the
// vertical dismiss and the horizontal day paging never fight each other.
struct WindowGestureHandler: UIViewRepresentable {
    let gestureFrame: CGRect
    let onGestureChange: (CGFloat, CGFloat, PanGestureState, PanGestureAxis) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        setupGestureIfPossible(view: view, context: context)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onGestureChange = onGestureChange
        context.coordinator.gestureFrame = gestureFrame

        if context.coordinator.gesture == nil {
            setupGestureIfPossible(view: uiView, context: context)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cleanUp()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(gestureFrame: gestureFrame)
    }

    private func findWindow(from view: UIView) -> UIWindow? {
        return view.window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })
    }

    private func setupGestureIfPossible(view: UIView, context: Context) {
        guard let targetWindow = findWindow(from: view) else { return }

        if let existingGesture = context.coordinator.gesture {
            existingGesture.view?.removeGestureRecognizer(existingGesture)
        }

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.maximumNumberOfTouches = 2
        panGesture.minimumNumberOfTouches = 1
        panGesture.delegate = context.coordinator
        // A drag that started on a row carries the row along with the finger — the pushed
        // screen on a swipe back moves one-to-one with it — so the touch can lift inside the
        // button it began on and the button fires. Cancelling once the pan is recognized is what
        // turns a drag back into "not a tap"; a tap never reaches recognition and is delivered
        // as before.
        panGesture.cancelsTouchesInView = true
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        panGesture.name = "DayDetailsSwipeToDismiss"

        targetWindow.addGestureRecognizer(panGesture)
        context.coordinator.gesture = panGesture
        context.coordinator.onGestureChange = onGestureChange
        context.coordinator.gestureFrame = gestureFrame
        Coordinator.current = context.coordinator
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        // A card that is transitioning out keeps its recognizer on the window until the
        // animation ends, and being the older one it would recognize first and answer for the
        // card that replaced it. Only the most recently installed one acts.
        static weak var current: Coordinator?

        var onGestureChange: ((CGFloat, CGFloat, PanGestureState, PanGestureAxis) -> Void)?
        var gestureFrame: CGRect
        weak var gesture: UIPanGestureRecognizer?

        private enum GestureDirection {
            case undecided, vertical, horizontal
        }

        private var gestureDirection: GestureDirection = .undecided
        // Where the first finger of the current gesture came down, in the window. Recorded as
        // the touch arrives rather than read when the pan begins: by then the finger is already
        // several points along, and a drag starting just outside the card would be let in.
        private var touchDownLocation: CGPoint?
        // Whether the vertical branch has been told that the gesture it was receiving turned out
        // to be a horizontal one. Sent once per gesture.
        private var endedVerticalPhase = false
        private let gestureDetectionThreshold: CGFloat = 5

        init(gestureFrame: CGRect) {
            self.gestureFrame = gestureFrame
        }

        func cleanUp() {
            if let gesture = gesture, let view = gesture.view {
                view.removeGestureRecognizer(gesture)
            }
            gesture = nil
            onGestureChange = nil

            if Coordinator.current === self {
                Coordinator.current = nil
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard Coordinator.current === self else { return }

            let translation = gesture.translation(in: gesture.view)
            let velocity = gesture.velocity(in: gesture.view)

            switch gesture.state {
            case .began:
                gestureDirection = .undecided
                endedVerticalPhase = false
                onGestureChange?(0, 0, .began, .vertical)

            case .changed:
                if gestureDirection == .undecided {
                    if abs(translation.x) > gestureDetectionThreshold || abs(translation.y) > gestureDetectionThreshold {
                        gestureDirection = abs(translation.y) >= abs(translation.x) ? .vertical : .horizontal
                    }
                }

                emit(translation: translation, velocity: velocity, state: .changed)

            case .ended:
                emit(translation: translation, velocity: velocity, state: .ended)
                gestureDirection = .undecided

            case .cancelled, .failed:
                emit(translation: translation, velocity: velocity, state: .cancelled)
                gestureDirection = .undecided

            default:
                break
            }
        }

        private func emit(translation: CGPoint, velocity: CGPoint, state: PanGestureState) {
            switch gestureDirection {
            case .horizontal:
                // Until the axis was settled this gesture was going to the vertical branch, which
                // has been following it with the card. That phase is over now, and without saying
                // so the card would be left held a few points down.
                if !endedVerticalPhase {
                    endedVerticalPhase = true
                    onGestureChange?(0, 0, .cancelled, .vertical)
                }

                onGestureChange?(translation.x, velocity.x, state, .horizontal)
            case .vertical, .undecided:
                onGestureChange?(translation.y, velocity.y, state, .vertical)
            }
        }

        // A sheet is presented into the same window this recognizer is attached to, so it goes
        // on seeing touches that belong to the sheet: a drag anywhere in the tag picker was
        // moving the card underneath it, and — since this recognizer refuses to run alongside
        // any other — the picker's own scroll view had to win a race against it to scroll at
        // all. Only the topmost thing on screen answers a drag, so nothing does while anything
        // is presented over the app.
        //
        // And only a drag that began on the card is the card's. Outside it the vertical dismiss
        // used to answer the whole window, which went unnoticed over the calendar only because
        // the scroll view's own pan wins the race there. Where nothing else competes — the
        // navigation bar, the weekday strip — a scroll pulled the card down instead.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let window = gestureRecognizer.view as? UIWindow ?? gestureRecognizer.view?.window
            guard window?.rootViewController?.presentedViewController == nil else { return false }
            guard let touchDownLocation else { return false }
            return gestureFrame.contains(touchDownLocation)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if gestureRecognizer.numberOfTouches == 0 {
                touchDownLocation = touch.location(in: gestureRecognizer.view)
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
    }
}
