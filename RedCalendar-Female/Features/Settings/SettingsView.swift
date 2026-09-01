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

    /// The switch's own position while the write goes round, exactly as `ProfileView` holds its
    /// three: `nil` until it is touched, the store's answer until then. A `Toggle` bound straight
    /// to state would spring back under the finger and land again a GRDB round trip later.
    ///
    /// It masks a change made on another device for as long as this screen is open, which is the
    /// same trade the three editors on `ProfileView` make and the same reason: a value being
    /// edited here is the one the person is looking at.
    @State private var draftNotificationsEnabled: Bool?

    private let devModeTapThreshold: CFTimeInterval = 0.5
    private let swatchSize: CGFloat = 22

    var body: some View {
        NavigationView {
            if let deviceId = store.state.deviceId {
                Form {
                    profileSection

                    notificationsSection

                    accentThemeSection

                    Section("Теги") {
                        NavigationLink("Редактировать") {
                            TagsListView()
                        }
                    }

                    Section {
                        versionRow
                    }

                    if versionTapCount >= 8 {
                        DeveloperSectionView(
                            deviceId: deviceId,
                            todayDayStamp: store.state.calendarState.todayDayStamp,
                            analyticsActivated: store.state.analyticsActivated,
                            pushRegistered: store.state.notifications.pushPermissionState == .authorized
                                && store.state.notifications.apnsToken != nil,
                            userName: store.state.userProfile?.name,
                            userEmail: store.state.userProfile?.email,
                            userPhoneNumber: store.state.userProfile?.phoneNumber
                        )
                    }

                    Section {
                        // The accent from the tint, not the system red a destructive button
                        // would take. Logout drops the session, not the local database, so the
                        // warning colour a truly destructive action gets — "Удалить аккаунт", one
                        // screen away on the profile row above — is not owed here.
                        Button("Выйти") {
                            store.send(.auth(.logout))
                        }
                    }
                }
                .navigationTitle("Настройки")
                .navigationBarTitleDisplayMode(.inline)
                .closeButtonToolbar()
            }
        }
    }

    // MARK: - Private Views

    // One navigable row into everything that identifies the account or shapes what the calendar
    // predicts with — name, email, cycle length, period length, and the account's own destructive
    // action — first on the screen because it identifies whose settings these are before getting
    // to what they are. A static title-and-caption row, not the Apple-ID-style name-over-email
    // preview this used to be: once the destination held more than identity, a row that could
    // only preview two of its five fields stopped telling the truth about what tapping it opens.
    // `ProfileView` is where each of those fields actually lives; this row only names the
    // destination.
    private var profileSection: some View {
        Section {
            NavigationLink {
                ProfileView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Профиль")
                        Text("Имя, email и цикл")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)

                    // A missing email is not just an unfilled field today — phone sign-in is on
                    // its way out (see `ProfileView`'s footer) — so the row surfaces it before the
                    // person ever opens the screen, the same way `HomeView` surfaces a write
                    // failure rather than leaving it for the settings screen to explain quietly.
                    if store.state.userProfile?.email == nil {
                        Spacer()
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .accessibilityLabel("Не указан email")
                    }
                }
            }
        }
    }

    // Above the theme picker and below the profile row, because it is the other row on this
    // screen that changes what the *account* does rather than what this phone looks like.
    //
    // The switch is disabled — not hidden — when iOS has been told no. Hiding it would leave a
    // person who denied the alert once with no explanation at all for why nothing ever arrives,
    // and the answer is not in this app. It draws off in that state whatever the account's own
    // preference is, because off is what this phone will actually do.
    private var notificationsSection: some View {
        let isBlocked = store.state.notifications.isBlockedBySystem

        return Section("Уведомления") {
            Toggle("Присылать уведомления", isOn: notificationsBinding)
                .disabled(isBlocked)

            if isBlocked {
                SystemNotificationsNote()
            }
        }
    }

    // Rows rather than a `Picker`: the thing being chosen is a colour, so each option has to
    // show its own colour at a size worth judging. A picker would collapse the three down to
    // their names.
    private var accentThemeSection: some View {
        Section("Оформление") {
            ForEach(AccentTheme.allCases) { theme in
                let isSelected = store.state.accentTheme == theme

                Button {
                    store.send(.appearance(.setAccentTheme(theme)))
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: swatchSize, height: swatchSize)

                        Text(theme.title)
                            .foregroundColor(.primary)

                        Spacer()

                        // Always laid out, only faded: inserting and removing the glyph made the
                        // row taller the moment a theme was picked. Boxed to the swatch's size so
                        // it never drives the row height either — a checkmark's ascender is
                        // taller than the text line it sits next to.
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(theme.accent)
                            .frame(width: swatchSize, height: swatchSize)
                            .opacity(isSelected ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
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

    // MARK: - Private Methods

    // The draft is ignored the moment the system says no: a switch left showing the position the
    // user chose a second ago — while the permission alert they were just shown was denied — would
    // be the one thing on screen still claiming notifications are coming.
    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: {
                guard !store.state.notifications.isBlockedBySystem else { return false }
                return draftNotificationsEnabled ?? store.state.notifications.isAllowedByPreference
            },
            set: { enabled in
                draftNotificationsEnabled = enabled
                // Undebounced, unlike the steppers: one flick is the whole intent, and there are
                // no intermediate values to coalesce. Asking iOS for permission is not done here
                // — the write comes back through the profile observation and
                // `PushNotificationsMiddleware` decides from it, which is what makes this screen
                // and the onboarding screen and another device all behave identically.
                store.send(.data(.setNotificationsEnabled(enabled)))
            }
        )
    }
}

private struct DeveloperSectionView: View {
    let deviceId: String
    let todayDayStamp: Daystamp
    let analyticsActivated: Bool
    let pushRegistered: Bool
    let userName: String?
    let userEmail: String?
    let userPhoneNumber: String?

    // The placeholder for a field the profile row simply has nothing in — a device never writes
    // `name`/`email`/`phone_number` itself (§4.4), so an unset one here means the server has
    // never sent a value, not that this screen failed to read it.
    //
    // `fileprivate`, not `private`: `Optional.orPlaceholder` below reads it from an extension on
    // a different type, and same-file `private` access only reaches extensions of the *same*
    // type, not another type's extension living in the same file.
    // `nonisolated`: a `View`'s stored statics infer `@MainActor` from the conformance, and
    // `Optional.orPlaceholder` is a nonisolated extension member.
    nonisolated fileprivate static let unsetPlaceholder = "—"

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
                Text("Имя")
                Spacer()
                Text(userName.orPlaceholder)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Text("Почта")
                Spacer()
                Text(userEmail.orPlaceholder)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Text("Телефон")
                Spacer()
                Text(userPhoneNumber.orPlaceholder)
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

private extension Optional where Wrapped == String {
    // A field can also come back empty rather than absent — an empty string is not a value
    // either, so it gets the same dash a `nil` does.
    var orPlaceholder: String {
        guard let self, !self.isEmpty else { return DeveloperSectionView.unsetPlaceholder }
        return self
    }
}

#Preview {
    SettingsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test-device-id"),
                    notifications: NotificationState(
                        apnsToken: APNSToken(value: "test-token", isSynced: true),
                        pushPermissionState: .authorized
                    ),
                    analyticsActivated: true,
                    userProfile: UserDetails(
                        userId: "test-user-id",
                        name: "Анна",
                        email: "anna@example.com",
                        phoneNumber: nil,
                        settings: nil
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("Уведомления запрещены в iOS") {
    SettingsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test-device-id"),
                    notifications: NotificationState(
                        apnsToken: nil,
                        pushPermissionState: .denied,
                        preference: .enabled
                    ),
                    userProfile: UserDetails(
                        userId: "test-user-id",
                        name: "Анна",
                        email: "anna@example.com",
                        phoneNumber: nil,
                        settings: nil
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("Без имени и email (RedCalendar 2.0)") {
    SettingsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test-device-id"),
                    notifications: NotificationState(
                        apnsToken: APNSToken(value: "test-token", isSynced: true),
                        pushPermissionState: .authorized
                    ),
                    analyticsActivated: true,
                    userProfile: UserDetails(
                        userId: "test-user-id",
                        name: nil,
                        email: nil,
                        phoneNumber: "+70000000000",
                        settings: nil
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
