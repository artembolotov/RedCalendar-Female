//
//  DayCardLayout.swift
//  RedCalendar-Female
//

import SwiftUI

enum DayDetailsMetrics {
    // The card's inset from the screen edge. `DayDetailsPagerView` reuses it as the gap
    // between two cards, so it has to be an explicit shared number rather than the
    // system's default padding.
    static let screenInset: CGFloat = 16
    // A single-line row with its value or checkmark at the trailing edge — the card's own
    // "Обильность" and "Статус" and the options on the screens they push. One number, so moving
    // from a row to the list it opens does not change how dense a row is.
    static let valueRowVerticalPadding: CGFloat = 15
    // The smallest target a tap is expected to hit is 44pt. The card's chips (32 at the default
    // text size) and its close button (30) are drawn smaller and take the difference as an
    // invisible margin — see `tapTargetMargin(_:)`.
    static let chipTapMargin: CGFloat = 6
    static let closeButtonTapMargin: CGFloat = 7
}

/// A card height together with the day it belongs to.
///
/// The calendar centres the selected day in the space above the card, so it cannot leave until
/// it knows how tall the card for *that* day is. The day travels with the number because the
/// number alone is not the signal: a card keeping its level across a day change reports the same
/// height for a new day, and a new day whose content happens to measure the same as the last
/// one's would otherwise never be reported at all.
struct DayCardHeight: Equatable {
    var day: Daystamp?
    var height: CGFloat

    static let none = DayCardHeight(day: nil, height: 0)
}

// Height the active card's content asks for, reported from inside the card's own layout so the
// pager can decide when to move every card to it. Inactive cards contribute `.none`.
struct DayCardNaturalHeightKey: PreferenceKey {
    static var defaultValue: DayCardHeight { .none }

    static func reduce(value: inout DayCardHeight, nextValue: () -> DayCardHeight) {
        let next = nextValue()
        if next.height > 0 {
            value = next
        }
    }
}

// The active card's box, reported up to the pager: it drives the drag gesture's hit test.
// Inactive cards contribute `.zero`. The calendar's centering does not come from here — it is
// written from the level, in `reportedHeight`'s unit, which is the card alone.
struct DayCardFrameKey: PreferenceKey {
    static var defaultValue: CGRect { .zero }

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

extension View {
    /// Widens what takes a tap past the view's own edges, without changing what is drawn or how
    /// much room the view takes in its layout. Also closes the holes a hollow control has: a
    /// stroked outline alone takes a tap only on the stroke.
    func tapTargetMargin(_ margin: CGFloat) -> some View {
        contentShape(Rectangle().inset(by: -margin))
    }
}
