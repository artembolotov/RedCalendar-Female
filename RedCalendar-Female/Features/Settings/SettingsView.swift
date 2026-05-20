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
    @State private var developerUnlocked = false

    var body: some View {
        NavigationView {
            if case .authenticated(let deviceId, _, _) = store.state.authState {
                Form {
                    Section {
                        versionRow
                    }

                    if developerUnlocked {
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
        Button {
            versionTapCount += 1
            if versionTapCount >= 8 {
                developerUnlocked = true
            }
        } label: {
            HStack {
                Text("Версия")
                    .foregroundColor(.primary)
                Spacer()
                Text(Bundle.main.versionString)
                    .foregroundColor(.secondary)
            }
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
        store.state.pushPermissionState == .authorized && store.state.apnsToken != nil
    }
}

#Preview {
    SettingsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: APNSToken(value: "test-token", isSynced: true),
                    authState: .authenticated(
                        deviceId: "test-device-id",
                        userDetails: nil,
                        calendarState: CalendarState()
                    ),
                    pushPermissionState: .authorized,
                    analyticsActivated: true
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
