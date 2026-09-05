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

    /// What the trailing toolbar spinner actually draws. Deliberately not `devices.isLoading`
    /// itself — `reconcileIndicator(isLoading:)` only flips this on once
    /// `indicatorAppearDelayNanoseconds` has passed with the load still not answered, so a
    /// request that resolves inside that window never draws a spinner at all. See
    /// `SyncIndicatorView`, which the same scheme is copied from.
    @State private var isIndicatorVisible = false
    @State private var indicatorAppearTask: Task<Void, Never>?

    // Same duration and same reason as `SyncIndicatorView.fadeDuration`: a state change made
    // from a `Task.sleep` resuming, rather than a direct SwiftUI event, is not reliably caught by
    // an ambient `.animation(value:)` — wrapping the mutation itself in `withAnimation` is.
    private let indicatorFadeDuration: TimeInterval = 0.2

    private var devices: DevicesState { store.state.devices ?? DevicesState() }

    var body: some View {
        List {
            if let failure = devices.failure {
                Section {
                    Text(failure.message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Common.Retry") {
                        store.send(.devices(.load))
                    }
                    .font(.footnote)
                }
            }

            Section {
                ForEach(devices.devices) { device in
                    row(for: device)
                }

                // Said once, under the list, rather than on the row it applies to: it explains
                // what happens to the *other* phone, which is not what the marked row is about.
                //
                // A row in the section's own content, not `footer:` — a `Section` footer is a
                // distinct supplementary view with its own self-sizing pass, separate from its
                // rows', and that pass comes back from a background/foreground cycle unstable
                // (confirmed on device for the same text elsewhere; `.fixedSize` on the footer
                // text does not fix it — see `ProfileView`'s cycle-length section for the same
                // workaround). Folding the text into the row content shares the rows' own
                // self-sizing pass instead of getting one of its own.
                if !devices.devices.isEmpty {
                    Text("Отключённое устройство выйдет из аккаунта, когда приложение на нём в следующий раз выйдет в сеть.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Мои устройства")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(DevicesToolbar(isIndicatorVisible: isIndicatorVisible))
        .onChange(of: devices.isLoading) { reconcileIndicator(isLoading: $0) }
        .onAppear { store.send(.devices(.load)) }
        .onDisappear {
            store.send(.devices(.close))
            indicatorAppearTask?.cancel()
        }
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

    /// Gates *appearing*, never disappearing — same rule as `SyncIndicatorView.reconcile(to:)`.
    /// A load that finishes is applied immediately; a load that just started only draws a spinner
    /// once it has been running long enough that showing one is worth the flash of chrome.
    private func reconcileIndicator(isLoading: Bool) {
        indicatorAppearTask?.cancel()
        indicatorAppearTask = nil

        guard isLoading else {
            withAnimation(.easeInOut(duration: indicatorFadeDuration)) {
                isIndicatorVisible = false
            }
            return
        }

        indicatorAppearTask = Task {
            try? await Task.sleep(nanoseconds: Constants.Devices.indicatorAppearDelayNanoseconds)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: indicatorFadeDuration)) {
                isIndicatorVisible = true
            }
        }
    }

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

/// Same reason as `HomeToolbar` (`HomeView.swift`) — see its doc comment. `.sharedBackgroundVisibility`
/// (iOS 26+) is a `ToolbarContent` modifier, not a `View` one, so hiding the system's "Liquid
/// Glass" background at `.idle` needs the `if #available … else` to branch the `.toolbar {}` call
/// itself; `ProgressView`'s own `.opacity(0)` never reaches that background, which is keyed off
/// whether the item has content at all, not off what that content currently renders as.
private struct DevicesToolbar: ViewModifier {
    let isIndicatorVisible: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProgressView()
                        .opacity(isIndicatorVisible ? 1 : 0)
                        .accessibilityHidden(!isIndicatorVisible)
                }
                .sharedBackgroundVisibility(isIndicatorVisible ? .visible : .hidden)
            }
        } else {
            content.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProgressView()
                        .opacity(isIndicatorVisible ? 1 : 0)
                        .accessibilityHidden(!isIndicatorVisible)
                }
            }
        }
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
