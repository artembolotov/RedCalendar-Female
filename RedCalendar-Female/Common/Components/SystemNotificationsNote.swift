//
//  SystemNotificationsNote.swift
//  RedCalendar-Female
//

import SwiftUI
import UIKit

/// Why the notifications switch is off and greyed out, and the one thing that can change it.
///
/// Shared by the two screens that show that switch — `SettingsView` and `CycleOnboardingView` —
/// because the situation is the same on both and the sentence explaining it should not exist
/// twice. There is nothing this app can do about a system-level refusal: `requestAuthorization`
/// on a denied app returns immediately without showing anything, so the only honest affordance is
/// a way out to the Settings app.
///
/// It says nothing about the account's own preference, which is deliberate: that preference is
/// untouched by this, and the person's other devices still honour it.
struct SystemNotificationsNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Уведомления отключены для приложения в настройках iOS. Включите их там, чтобы получать напоминания на этом устройстве.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Открыть настройки iOS", action: openSystemSettings)
                .font(.footnote)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Private Methods

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Preview

#Preview {
    Form {
        Section("Уведомления") {
            Toggle("Присылать уведомления", isOn: .constant(false))
                .disabled(true)
            SystemNotificationsNote()
        }
    }
}
