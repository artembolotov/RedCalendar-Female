//
//  View+ContextMenuPreviewShape.swift
//  RedCalendar-Female
//

import SwiftUI

extension View {
    /// What `.contextMenu` lifts on a long press, told explicitly rather than left to the
    /// system's own guess.
    ///
    /// Without this, the lift preview for a small, tightly-bordered view like `TagChip` is
    /// built from a heuristic snapshot rather than the view's real shape, and on a chip that is
    /// mostly padding and a 1pt stroke, that heuristic reads the border as a separate element —
    /// the preview draws the chip's outline and an underline under the text as two different
    /// things instead of one rounded rectangle, which is what showed up as brackets around the
    /// tag's name once the picker gained a long-press menu. `.contentShape(.contextMenuPreview:)`
    /// (iOS 16+) exists for exactly this: it hands the system the same shape the chip already
    /// draws with, so the lift is the chip, not the system's reconstruction of it.
    ///
    /// `iOS 15.4` is still this app's floor, so below 16 this is a no-op and the mismatch it
    /// fixes simply has no fix — the same split `ConfirmButton` makes for `ButtonRole.confirm`.
    @ViewBuilder
    func contextMenuPreviewShape<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 16.0, *) {
            self.contentShape(.contextMenuPreview, shape)
        } else {
            self
        }
    }
}
