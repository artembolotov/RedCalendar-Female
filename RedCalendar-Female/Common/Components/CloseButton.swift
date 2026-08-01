//
//  CloseButton.swift
//  RedCalendar-Female
//

import SwiftUI

// The system's own close control wherever it exists, a hand-drawn glyph only where it doesn't.
// From iOS 26 `ButtonRole.close` renders the platform's standard ✕ — and keeps rendering whatever
// it becomes in later releases — so nothing about its look is spelled out here. The guard is
// `#if compiler` and not `#available` alone because the role is absent from SDKs older than
// iOS 26: without it the file would not compile on Xcode 16.
struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss

    private let action: (() -> Void)?

    /// Dismisses the enclosing presentation.
    init() {
        self.action = nil
    }

    /// Runs `action` instead of the environment's dismiss — for presentations driven by a binding.
    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Button("Закрыть", role: .close, action: close)
        } else {
            fallbackButton
        }
        #else
        fallbackButton
        #endif
    }

    // MARK: - Private Views

    private var fallbackButton: some View {
        Button(action: close) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("Закрыть")
    }

    // MARK: - Private Methods

    private func close() {
        if let action {
            action()
        } else {
            dismiss()
        }
    }
}

extension View {
    /// Puts a `CloseButton` in the navigation bar's trailing corner, so every sheet in the app
    /// closes from the same place. Pass `action` when the sheet is driven by a binding rather
    /// than by the environment's dismiss.
    func closeButtonToolbar(action: (() -> Void)? = nil) -> some View {
        toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let action {
                    CloseButton(action: action)
                } else {
                    CloseButton()
                }
            }
        }
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
