//
//  KeyboardDismissGestureModifier.swift
//  RedCalendar-Female
//

import SwiftUI

// `.sheet` offers no hook for the *start* of an interactive dismissal — only `.onDisappear`,
// which fires once the closing animation has already finished, the same "too late" problem
// `CommentSheetView`'s own comment describes for saving. `.simultaneousGesture` reads the same
// touch stream the system's own dismiss-tracking pan gesture is already following, without
// claiming exclusivity over it, so this never competes with or delays the native swipe.
private struct KeyboardDismissGestureModifier: ViewModifier {
    @Binding var isFocused: Bool

    // Guards against re-ducking on every `.onChanged` tick once the threshold has been crossed
    // for this gesture — `isFocused = false` only needs to be sent once per swipe.
    @State private var hasDucked = false

    // A couple of points, not zero: `minimumDistance: 0` means a tap that merely places the
    // caret already carries a point or two of incidental translation, and that must not duck
    // the keyboard. Mirrors `WindowGestureHandler.gestureDetectionThreshold` (5pt) for the same
    // "is this an intentional move" question, with a bit more margin — the cost of a false
    // positive here is a keyboard flicker rather than a paging decision.
    private let duckThreshold: CGFloat = 8

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !hasDucked, value.translation.height > duckThreshold else { return }
                    hasDucked = true
                    isFocused = false
                }
                .onEnded { _ in
                    // Unconditional, not gated on how far the drag went: at touch-up there is no
                    // public way to know whether UIKit is about to confirm the dismissal or
                    // spring the sheet back — that decision is the system recognizer's own,
                    // position-and-velocity-based heuristic. A cancelled drag needs the keyboard
                    // back; a confirmed one is tearing this view down anyway, so refocusing here
                    // costs at most a brief flicker during the closing animation.
                    hasDucked = false
                    isFocused = true
                }
        )
    }
}

extension View {
    /// Ducks the keyboard as an interactive sheet-dismiss swipe begins, and restores focus if
    /// the swipe is released without crossing the sheet's own dismiss point. Attach to the same
    /// node that owns `isFocused` (typically the sheet's root `NavigationView`), alongside the
    /// existing `.task { isFocused = true }` that sets initial focus.
    func duckKeyboardOnInteractiveDismiss(isFocused: Binding<Bool>) -> some View {
        modifier(KeyboardDismissGestureModifier(isFocused: isFocused))
    }
}
