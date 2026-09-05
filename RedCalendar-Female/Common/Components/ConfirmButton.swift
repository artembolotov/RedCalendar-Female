//
//  ConfirmButton.swift
//  RedCalendar-Female
//

import SwiftUI

// The system's own confirm control wherever it exists, a plain text button only where it doesn't.
// From iOS 26 `ButtonRole.confirm` renders the platform's standard blue checkmark — and keeps
// rendering whatever it becomes in later releases — so nothing about its look, and no
// accessibility label, is spelled out on that path. Below iOS 26 the role does not exist and the
// button falls back to its title as plain text, the way a `.confirmationAction` toolbar button
// always has.
struct ConfirmButton: View {
    let title: LocalizedStringKey
    let isEnabled: Bool
    let action: () -> Void

    init(_ title: LocalizedStringKey, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(role: .confirm, action: action)
            } else {
                Button(title, action: action)
            }
        }
        .disabled(!isEnabled)
    }
}

#Preview {
    NavigationView {
        Text("Содержимое")
            .navigationTitle("Экран")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton("Common.Done") {}
                }
            }
    }
}
