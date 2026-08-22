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

    private let cornerRadius: CGFloat = 8

    var body: some View {
        Button(action: action) {
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
        }
        // Without an explicit style, a `Button` renders its `.contextMenu` lift preview in the
        // system's default appearance rather than this view's own — the label loses its colour
        // and background and picks up an underline, which is what showed as brackets around the
        // text when the tag picker gained a long-press menu. `.plain` tells SwiftUI the chip's
        // own drawing already *is* the interactive appearance, so the preview matches the chip.
        .buttonStyle(.plain)
        .accessibilityAddTraits(isFilled ? [.isSelected] : [])
    }
}

#Preview {
    VStack(spacing: 12) {
        TagChip(title: "Головная боль", color: TagCategory.symptom.color, isFilled: false) {}
        TagChip(title: "Головная боль", color: TagCategory.symptom.color, isFilled: true) {}
    }
}
