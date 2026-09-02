//
//  DevicesView.swift
//  RedCalendar-Female
//

import SwiftUI

/// The sessions on the account (SYNC.md §19) — what is signed in, and a way to end any of them
/// but this one.
///
/// The list is fetched on every appearance and dropped on disappearance (`AppState.devices`),
/// because it is server truth about what may reach the account right now: a cached row would go
/// on claiming a session that somebody has already ended from another phone.
///
/// This device is in the list, marked, and cannot be revoked from here (§19.3). Ending it is
/// signing out — which also wipes the local database (§6) — and it has its own button one screen
/// back; a second path into it through a row of this list would skip the wipe.
struct DevicesView: View {
    @EnvironmentObject var store: AppStore

    private var devices: DevicesState { store.state.devices ?? DevicesState() }

    var body: some View {
        List {
            if let failure = devices.failure {
                Section {
                    Text(failure.message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Повторить") {
                        store.send(.devices(.load))
                    }
                    .font(.footnote)
                }
            }

            Section {
                ForEach(devices.devices) { device in
                    row(for: device)
                }
            } footer: {
                // Said once, under the list, rather than on the row it applies to: it explains
                // what happens to the *other* phone, which is not what the marked row is about.
                if !devices.devices.isEmpty {
                    Text("Отключённое устройство выйдет из аккаунта, когда приложение на нём в следующий раз выйдет в сеть.")
                }
            }
        }
        .navigationTitle("Мои устройства")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            // Only while there is nothing to show. A refresh over an existing list would move
            // the rows under a finger that is reaching for one of them.
            if devices.isLoading && devices.devices.isEmpty {
                ProgressView()
            }
        }
        .onAppear { store.send(.devices(.load)) }
        .onDisappear { store.send(.devices(.close)) }
    }

    // MARK: - Private Views

    @ViewBuilder
    private func row(for device: UserDevice) -> some View {
        let isCurrent = device.id == store.state.deviceId
        let isRevoking = devices.revoking.contains(device.id)

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)

                Text(subtitle(for: device, isCurrent: isCurrent))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)

            Spacer()

            if isRevoking {
                ProgressView()
            } else if isOnline(device, isCurrent: isCurrent) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
            }
        }
        .swipeActions(edge: .trailing) {
            // The current device has no action at all — the server refuses it too (§19.3), so
            // this is the affordance matching the rule rather than the rule itself.
            if !isCurrent && !isRevoking {
                Button("Отключить", role: .destructive) {
                    store.send(.devices(.revoke(deviceId: device.id)))
                }
            }
        }
    }

    // MARK: - Private Methods

    // This phone is online by definition — it is the one drawing the list, and the run that
    // filled it has just stamped its own row. Every other row is judged by how recently its own
    // run stamped it.
    private func isOnline(_ device: UserDevice, isCurrent: Bool) -> Bool {
        if isCurrent {
            return true
        }

        guard let lastSeenAt = device.lastSeenAt else {
            return false
        }

        return Date().timeIntervalSince(lastSeenAt) < Constants.Devices.onlineWindow
    }

    // "This device" replaces the activity line rather than joining it: on this phone the answer
    // is always "seconds ago" — the run that filled the list has just written it — and a
    // freshness reading is only worth reading about the phones that are not in your hand.
    private func subtitle(for device: UserDevice, isCurrent: Bool) -> String {
        if isCurrent {
            return "Это устройство"
        }

        guard let lastSeenAt = device.lastSeenAt else {
            // A device that signed in and never completed a sync run. Rare — signing in starts
            // one immediately — but its row has nothing else to say.
            return "Нет данных об активности"
        }

        return "Активность: \(lastSeenAt.formatted(.relative(presentation: .named)))"
    }
}

#Preview {
    NavigationView {
        DevicesView()
            .environmentObject(
                AppStore(
                    initialState: AppState(
                        authState: .authenticated(deviceId: "test-device-id"),
                        devices: DevicesState(devices: [
                            UserDevice(id: "test-device-id", name: "iPhone 16 Pro", lastSeenAt: Date()),
                            UserDevice(
                                id: "online-device-id",
                                name: "iPad Pro 11",
                                lastSeenAt: Date().addingTimeInterval(-120)
                            ),
                            UserDevice(
                                id: "other-device-id",
                                name: "iPhone 13",
                                lastSeenAt: Date().addingTimeInterval(-86_400 * 3)
                            ),
                            UserDevice(id: "never-synced-id", name: "iPhone19,1", lastSeenAt: nil)
                        ])
                    ),
                    reducer: appReducer,
                    middlewares: []
                )
            )
    }
}

#Preview("Не загрузился") {
    NavigationView {
        DevicesView()
            .environmentObject(
                AppStore(
                    initialState: AppState(
                        authState: .authenticated(deviceId: "test-device-id"),
                        devices: DevicesState(failure: .load)
                    ),
                    reducer: appReducer,
                    middlewares: []
                )
            )
    }
}
