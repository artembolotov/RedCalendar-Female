//
//  KeyboardDismissGestureModifier.swift
//  RedCalendar-Female
//

import SwiftUI

// `.sheet` offers no hook for the *start* of an interactive dismissal — only `.onDisappear`,
// which fires once the closing animation has already finished, the same "too late" problem
// `CommentSheetView`'s own comment describes for saving. `SheetDismissGestureTracker` reads the
// same touch stream the system's own dismiss-tracking pan gesture is already following, without
// claiming exclusivity over it — see that file for why a plain SwiftUI `DragGesture` could not
// do this instead.
private struct KeyboardDismissGestureModifier: ViewModifier {
    // `$isFocused` off an `@FocusState` projects `FocusState<Bool>.Binding`, not
    // `SwiftUI.Binding<Bool>` — the two don't implicitly convert, so the modifier takes the
    // type `@FocusState` actually produces rather than forcing call sites to wrap it.
    var isFocused: FocusState<Bool>.Binding

    // Guards against re-ducking on every `.changed` tick once the threshold has been crossed
    // for this gesture — `isFocused = false` only needs to be sent once per swipe.
    @State private var hasDucked = false

    // Not zero: a stray couple of points of vertical drift before `UIPanGestureRecognizer`'s
    // own recognition slop kicks in must not duck the keyboard on its own. Mirrors
    // `WindowGestureHandler.gestureDetectionThreshold` (5pt) for the same "is this an
    // intentional move" question, with a bit more margin — the cost of a false positive here is
    // a keyboard flicker rather than a paging decision.
    private let duckThreshold: CGFloat = 8

    func body(content: Content) -> some View {
        content.background(
            SheetDismissGestureTracker { translationY, state in
                switch state {
                case .changed:
                    guard !hasDucked, translationY > duckThreshold else { return }
                    hasDucked = true
                    isFocused.wrappedValue = false

                case .ended, .cancelled, .failed:
                    // Unconditional, not gated on how far the drag went: at touch-up there is no
                    // public way to know whether UIKit is about to confirm the dismissal or
                    // spring the sheet back — that decision is the system recognizer's own,
                    // position-and-velocity-based heuristic. A cancelled drag needs the keyboard
                    // back; a confirmed one is tearing this view down anyway, so refocusing here
                    // costs at most a brief flicker during the closing animation.
                    hasDucked = false
                    isFocused.wrappedValue = true

                default:
                    break
                }
            }
        )
    }
}

extension View {
    /// Ducks the keyboard as an interactive sheet-dismiss swipe begins, and restores focus if
    /// the swipe is released without crossing the sheet's own dismiss point. Attach to the same
    /// node that owns `isFocused` (typically the sheet's root `NavigationView`), alongside the
    /// existing `.task { isFocused = true }` that sets initial focus.
    func duckKeyboardOnInteractiveDismiss(isFocused: FocusState<Bool>.Binding) -> some View {
        modifier(KeyboardDismissGestureModifier(isFocused: isFocused))
    }
}
