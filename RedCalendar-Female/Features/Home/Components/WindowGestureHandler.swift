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
// has to answer drags that start anywhere over it, including on top of its own scrollable
// content. The axis is decided once per gesture, so the vertical dismiss and the horizontal
// day paging never fight each other.
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
        panGesture.cancelsTouchesInView = false
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
        private var beganInsideFrame = false
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
                beganInsideFrame = gestureFrame.contains(gesture.location(in: gesture.view))
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

        // Paging is limited to drags that started over the card; the vertical dismiss keeps
        // answering the whole window as it always has.
        private func emit(translation: CGPoint, velocity: CGPoint, state: PanGestureState) {
            switch gestureDirection {
            case .horizontal:
                guard beganInsideFrame else { return }
                onGestureChange?(translation.x, velocity.x, state, .horizontal)
            case .vertical, .undecided:
                onGestureChange?(translation.y, velocity.y, state, .vertical)
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
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
