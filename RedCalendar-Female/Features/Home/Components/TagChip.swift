//
//  TagChip.swift
//  RedCalendar-Female
//

import SwiftUI

/// The vocabulary the tag picker is written in: outlined when the tag is not on the day and
/// filled when it is, rather than a difference in shade. A chip is small enough that a step in
/// density has no area to read in, and the day card already draws an assigned tag as an outline
/// of its category's colour.
///
/// The creation form draws bare colour swatches rather than these, because a category has no
/// name to put in a chip — see `TagCategory`. What the two screens share is the colour, not the
/// shape.
struct TagChip: View {
    let title: String
    let color: Color
    let isFilled: Bool
    let action: () -> Void
    /// A held press, separate from `action` because it means something different: a tap assigns
    /// or unassigns the tag, a hold goes to edit it. Defaulted to a no-op rather than made
    /// optional — the gesture is always attached (an idle recognizer costs nothing to carry),
    /// only what it does varies by caller.
    var onLongPress: () -> Void = {}

    private let cornerRadius: CGFloat = 8

    // `Button` used to give this for free — every press dimmed its label the instant a finger
    // came down, tap or hold alike, and let go the instant it lifted. Dropping `Button` (see the
    // gesture comment below) dropped that with it: nothing here told a finger holding still on a
    // chip that anything was happening, right up until either a tap toggled the day's tag or a
    // held one opened the editor. `isPressed` is what puts it back — read by `.onLongPressGesture`
    // `pressing:`, which reports the finger down at touch-down and up at release, independent of
    // whether the hold ever reaches `onLongPress`.
    @State private var isPressed = false

    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(isFilled ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isFilled ? color : Color.clear)
            )
            // `strokeBorder` rather than `stroke`, so the outline stays inside the chip's
            // own bounds instead of straddling them — that is what keeps the outlined and
            // the filled chip exactly the same size, and it is what the day card draws.
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(color, lineWidth: 1)
            )
            // The whole chip takes the tap, not just the glyphs in it. An unfilled chip is
            // a word, a clear fill and a hairline outline, so without this the padding
            // between the word and the outline is a hole in the target — on a chip six
            // points tall either side of the text, a tap that missed by nothing at all.
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            // The same dim a plain `Button` gives its label while held, restored by hand: half
            // opacity, gone the instant the finger lifts whichever way the press resolved.
            .opacity(isPressed ? 0.5 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressed)
            // Not a `Button`, so `.onTapGesture` and `.onLongPressGesture` can sit on the same
            // view and stay mutually exclusive on their own: a quick release fails the long-press
            // recognizer before it ever fires, a held one fires it and never reaches the tap.
            // `Button` composes far less predictably with a second gesture layered on top of it
            // — its own recognizer is what produced the `.contextMenu` preview mismatch this chip
            // used to carry (see git history), and stacking `.onLongPressGesture` on a `Button`
            // has the same kind of trouble: nothing here promises the two won't both fire once.
            .onTapGesture(perform: action)
            .onLongPressGesture(
                pressing: { isPressed = $0 },
                perform: onLongPress
            )
            .accessibilityAddTraits(isFilled ? [.isButton, .isSelected] : [.isButton])
    }
}

#Preview {
    VStack(spacing: 12) {
        TagChip(title: "Головная боль", color: TagCategory.symptom.color, isFilled: false) {}
        TagChip(title: "Головная боль", color: TagCategory.symptom.color, isFilled: true) {}
    }
}
