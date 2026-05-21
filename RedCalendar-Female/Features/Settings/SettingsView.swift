//
//  SettingsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.07.2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @State private var versionTapCount = 0

    var body: some View {
        NavigationView {
            if case .authenticated(let deviceId, _) = store.state.authState {
                Form {
                    Section {
                        versionRow
                    }

                    if versionTapCount >= 8 {
                        developerSection(deviceId: deviceId)
                    }

                    Section {
                        Button("Выйти") {
                            store.send(.logout)
                        }
                        .foregroundColor(.red)
                    }
                }
                .navigationTitle("Настройки")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Private Views

    private var versionRow: some View {
        HStack {
            Text("Версия")
            Spacer()
            Text(Bundle.main.versionString)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            versionTapCount += 1
        }
    }

    private func developerSection(deviceId: String) -> some View {
        Section("Developer") {
            HStack {
                Text("Device ID")
                Spacer()
                Text(deviceId)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            HStack {
                Text("AppMetrica")
                Spacer()
                statusCircle(active: store.state.analyticsActivated)
            }

            HStack {
                Text("Push-уведомления")
                Spacer()
                statusCircle(active: pushRegistered)
            }
        }
    }

    private func statusCircle(active: Bool) -> some View {
        Circle()
            .fill(active ? Color.green : Color.red)
            .frame(width: 10, height: 10)
    }

    // MARK: - Private Helpers

    private var pushRegistered: Bool {
        store.state.notifications.pushPermissionState == .authorized && store.state.notifications.apnsToken != nil
    }
}

#Preview {
    SettingsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test-device-id", userDetails: nil),
                    notifications: NotificationState(
                        apnsToken: APNSToken(value: "test-token", isSynced: true),
                        pushPermissionState: .authorized
                    ),
                    analyticsActivated: true
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
