//
//  CloseButton.swift
//  RedCalendar-Female
//

import SwiftUI

// The system's own close control wherever it exists, a hand-drawn glyph only where it doesn't.
// From iOS 26 `ButtonRole.close` renders the platform's standard ✕ — and keeps rendering whatever
// it becomes in later releases — so nothing about its look, and no accessibility label, is spelled
// out on that path. Below iOS 26 the role does not exist and the glyph is drawn here.
//
// The button itself knows nothing about how it is dismissed, and that is deliberate: it is
// meant to live in a toolbar, and a toolbar is the one place a view must not read `\.dismiss`
// for itself. Toolbar content is hosted by UIKit's navigation bar, off to the side of the
// hierarchy that carries the sheet's presentation — the read there returns a `DismissAction`
// with nothing to dismiss, and calling it does nothing at all rather than failing. So the
// action is always handed in, from a view that sits in the sheet's own hierarchy.
struct CloseButton: View {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close, action: action)
        } else {
            fallbackButton
        }
    }

    // MARK: - Private Views

    private var fallbackButton: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("Common.Close")
    }
}

// A `ViewModifier` rather than a plain `toolbar` call in the extension below, purely so that
// `\.dismiss` is read here — at the point the modifier is attached, inside the sheet — and
// reaches the toolbar as an already-resolved closure.
private struct CloseButtonToolbarModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let action: (() -> Void)?

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CloseButton {
                    if let action {
                        action()
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension View {
    /// Puts a `CloseButton` in the navigation bar's trailing corner, so every sheet in the app
    /// closes from the same place. Defaults to the environment's dismiss; pass `action` for a
    /// presentation driven by a binding the caller owns.
    ///
    /// Attach it inside the presented view's own hierarchy — that position is what the dismiss
    /// is resolved against.
    func closeButtonToolbar(action: (() -> Void)? = nil) -> some View {
        modifier(CloseButtonToolbarModifier(action: action))
    }
}

#Preview {
    NavigationView {
        Text("Содержимое")
            .navigationTitle("Экран")
            .navigationBarTitleDisplayMode(.inline)
            .closeButtonToolbar()
    }
}
