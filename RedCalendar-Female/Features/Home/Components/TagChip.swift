//
//  TagChip.swift
//  RedCalendar-Female
//

import SwiftUI

/// The vocabulary both tag screens are written in: outlined when the thing is not chosen and
/// filled when it is, rather than a difference in shade. A chip is small enough that a step in
/// density has no area to read in, and the day card already draws an assigned tag as an outline
/// of its category's colour.
///
/// One type rather than one per screen, because the picker's tags and the creation form's
/// categories sit one sheet apart and a category chip is a promise about what the tag chip is
/// going to look like. Two copies of this would be two chances for that promise to go stale.
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
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TagChip(title: "Головная боль", color: TagCategory.symptom.color, isFilled: false) {}
        TagChip(title: "Головная боль", color: TagCategory.symptom.color, isFilled: true) {}
    }
}
