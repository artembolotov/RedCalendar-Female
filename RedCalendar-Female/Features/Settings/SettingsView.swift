//
//  SettingsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.07.2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationView {
            if case .authenticated(let deviceId, _, _) = store.state.authState {
                Form {
                    Section("Устройство") {
                        HStack {
                            Text("Device ID")
                            Spacer()
                            Text(deviceId)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    
                    Section {
                        HStack {
                            Text("Версия")
                            Spacer()
                            Text(Bundle.main.versionString)
                                .foregroundColor(.secondary)
                        }
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
}

#Preview {
    SettingsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticated(
                        deviceId: "test-device-id",
                        userDetails: nil,
                        calendarState: CalendarState()
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
