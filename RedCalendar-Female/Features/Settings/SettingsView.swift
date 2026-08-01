//
//  SettingsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.07.2025.
//

import QuartzCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @State private var versionTapCount = 0
    @State private var lastVersionTapTime: CFTimeInterval?

    private let devModeTapThreshold: CFTimeInterval = 0.5

    var body: some View {
        NavigationView {
            if let deviceId = store.state.deviceId {
                Form {
                    Section {
                        versionRow
                    }

                    accentThemeSection

                    if versionTapCount >= 8 {
                        DeveloperSectionView(
                            deviceId: deviceId,
                            todayDayStamp: store.state.calendarState.todayDayStamp,
                            analyticsActivated: store.state.analyticsActivated,
                            pushRegistered: store.state.notifications.pushPermissionState == .authorized
                                && store.state.notifications.apnsToken != nil
                        )
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

    // Rows rather than a `Picker`: the thing being chosen is a colour, so each option has to
    // show its own colour at a size worth judging. A picker would collapse the three down to
    // their names.
    private var accentThemeSection: some View {
        Section("Оформление") {
            ForEach(AccentTheme.allCases) { theme in
                Button {
                    store.send(.setAccentTheme(theme))
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 22, height: 22)

                        Text(theme.title)
                            .foregroundColor(.primary)

                        Spacer()

                        if store.state.accentTheme == theme {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundColor(theme.accent)
                        }
                    }
                }
                .accessibilityAddTraits(store.state.accentTheme == theme ? .isSelected : [])
            }
        }
    }

    private var versionRow: some View {
        HStack {
            Text("Версия")
            Spacer()
            Text(Bundle.main.versionString)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard versionTapCount < 8 else { return }
            let now = CACurrentMediaTime()
            if let last = lastVersionTapTime, now - last > devModeTapThreshold {
                versionTapCount = 1
            } else {
                versionTapCount += 1
            }
            lastVersionTapTime = now
        }
    }

}

private struct DeveloperSectionView: View {
    let deviceId: String
    let todayDayStamp: Daystamp
    let analyticsActivated: Bool
    let pushRegistered: Bool

    var body: some View {
        Section("Developer") {
            HStack {
                Text("Device ID")
                Spacer()
                Text(deviceId)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Text("Today Daystamp")
                Spacer()
                Text("\(todayDayStamp.rawValue)")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Text("AppMetrica")
                Spacer()
                statusCircle(active: analyticsActivated)
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
