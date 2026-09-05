//
//  EmailBindingView.swift
//  RedCalendar-Female
//

import SwiftUI

/// Binding an address to the account, and changing the one it has (SYNC.md §18.12). Two steps —
/// an address, then the code sent to it — presented as one sheet over `ProfileView`, because they
/// are one intention and backing out of the second means going back to the first, not leaving.
///
/// The state machine is `AppState.emailBinding`, not `@State`: a request is in flight across a
/// screen the person can swipe away, and the confirmation that lands has a sync run to ask for
/// whether or not anybody is still looking at it.
///
/// The two text fields *are* local — they are what is being typed, and the store only hears about
/// them when a button is pressed, exactly as on the sign-in screens.
struct EmailBindingView: View {
    @EnvironmentObject var store: AppStore

    @State private var emailText: String = ""
    @State private var codeInput: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case code
    }

    /// Whether the account already has an address. Read from the profile rather than from the
    /// binding state, because the first step happens before the server has said anything — and
    /// the server's own `isChange` is what the *second* step goes by.
    private var isChange: Bool { store.state.userProfile?.email != nil }

    var body: some View {
        NavigationView {
            Group {
                switch store.state.emailBinding {
                case .entry(let email, let error):
                    entryStep(email: email, error: error, isBusy: false)

                case .requesting(let email):
                    entryStep(email: email, error: nil, isBusy: true)

                case .codeEntry(let email, _, _, let error):
                    codeStep(email: email, error: error, isBusy: false)

                case .confirming(let email, _, _):
                    codeStep(email: email, error: nil, isBusy: true)

                case .done(let email, let changed, _):
                    doneStep(email: email, changed: changed)

                // The sheet is dismissing — its presentation is driven by this being `nil`.
                case nil:
                    Color.clear
                }
            }
            .navigationTitle(isChange ? "Изменение email" : "Привязка email")
            .navigationBarTitleDisplayMode(.inline)
            .closeButtonToolbar { store.send(.emailBinding(.set(nil))) }
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private func entryStep(email: String, error: EmailBindingError?, isBusy: Bool) -> some View {
        stepLayout {
            Text(isChange
                 ? "Введите новый адрес. Мы отправим на него код подтверждения."
                 : "Email — это вход в аккаунт. Мы отправим на него код подтверждения.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if isChange, let current = store.state.userProfile?.email {
                Text("Текущий адрес: \(current)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Email", text: $emailText)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .submitLabel(.continue)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .email)
                .onSubmit(requestCode)
                .formFieldStyle()
                .disabled(isBusy)

            errorText(error)

            // Said before the code is asked for, not after the address has already moved: on a
            // change, the letter to the old address is the whole of the protection (§18.6), and
            // the person deciding to press the button is who needs to know it is coming.
            if isChange {
                Text("На прежний адрес придёт письмо о смене с кнопкой возврата — на случай, если аккаунтом воспользовался кто-то посторонний. Она действует \(Constants.Account.emailRevertWindowDays.localizedDays).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(
                isEnabled: emailText.trimmingCharacters(in: .whitespacesAndNewlines).isValidEmail && !isBusy,
                accent: store.state.accentTheme.accent,
                action: requestCode
            ) {
                buttonLabel("Отправить код", isBusy: isBusy)
            }
        }
        .onAppear {
            if emailText.isEmpty { emailText = email }
            focusedField = .email
        }
    }

    @ViewBuilder
    private func codeStep(email: String, error: EmailBindingError?, isBusy: Bool) -> some View {
        let isCodeValid = codeInput.count == 6 && codeInput.allSatisfy { $0.isNumber }

        stepLayout {
            HStack {
                Button {
                    store.send(.emailBinding(.set(.entry(email: email))))
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(store.state.accentTheme.accent)
                }
                .offset(x: -10)
                .disabled(isBusy)

                Spacer()
            }

            Text("Код подтверждения отправлен на \(email)")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("Код из письма", text: $codeInput)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: .code)
                .onChange(of: codeInput) { newValue in
                    let filtered = String(newValue.prefix(6).filter { $0.isNumber })
                    if filtered != newValue {
                        codeInput = filtered
                    }
                }
                .formFieldStyle()
                .disabled(isBusy)

            errorText(error)

            Text("Не получили письмо?\n[Отправить код ещё раз](resend)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .environment(\.openURL, OpenURLAction { url in
                    if url.absoluteString == "resend", !isBusy {
                        codeInput = ""
                        store.send(.emailBinding(.set(.requesting(email: email))))
                    }
                    return .handled
                })

            PrimaryButton(
                isEnabled: isCodeValid && !isBusy,
                accent: store.state.accentTheme.accent,
                action: { confirmCode(email: email) }
            ) {
                buttonLabel("Common.Confirm", isBusy: isBusy)
            }
        }
        .onAppear { focusedField = .code }
    }

    @ViewBuilder
    private func doneStep(email: String, changed: Bool) -> some View {
        stepLayout {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(store.state.accentTheme.accent)

            if changed {
                // Neither "привязан" nor "изменён": the answer says the address moved, not which
                // of the two edges of §18.2 it was, and a letter that failed to send is a change
                // that would be announced here as a first binding.
                //
                // Nothing here about the letter to the old address — the entry step already said
                // that, before the button was pressed (§18.6). Nothing has changed since to make
                // it worth repeating.
                Text("Теперь ваш адрес — \(email). Входите в аккаунт по нему.")
                    .multilineTextAlignment(.center)
            } else {
                Text("Этот адрес уже привязан к вашему аккаунту.")
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(
                "Common.Done",
                accent: store.state.accentTheme.accent,
                action: { store.send(.emailBinding(.set(nil))) }
            )
        }
        .onAppear { focusedField = nil }
    }

    /// The frame the three steps share — same 320pt column and full-height centring the sign-in
    /// screens use, so a step that is three lines long does not sit at the top of an empty sheet.
    private func stepLayout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let step = content()

        return GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    step
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func errorText(_ error: EmailBindingError?) -> some View {
        if let error {
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func buttonLabel(_ title: LocalizedStringKey, isBusy: Bool) -> some View {
        if isBusy {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
        } else {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Actions

    private func requestCode() {
        let trimmed = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isValidEmail else { return }

        focusedField = nil
        codeInput = ""
        store.send(.emailBinding(.set(.requesting(email: trimmed))))
    }

    private func confirmCode(email: String) {
        guard case .codeEntry(_, let isChange, _, _) = store.state.emailBinding else { return }

        focusedField = nil
        store.send(.emailBinding(.set(.confirming(email: email, code: codeInput, isChange: isChange))))
    }
}

// MARK: - Preview

@MainActor
private func previewStore(_ binding: EmailBindingState, email: String? = nil) -> AppStore {
    AppStore(
        initialState: AppState(
            authState: .authenticated(deviceId: "test-device-id"),
            userProfile: UserDetails(
                userId: "test-user-id",
                name: "Анна",
                email: email,
                phoneNumber: "+70000000000",
                settings: nil
            ),
            emailBinding: binding
        ),
        reducer: appReducer,
        middlewares: []
    )
}

#Preview("Привязка") {
    EmailBindingView().environmentObject(previewStore(.entry()))
}

#Preview("Смена — адрес занят") {
    EmailBindingView().environmentObject(
        previewStore(.entry(email: "taken@example.com", error: .emailTaken(availableAfter: nil)),
                     email: "anna@example.com")
    )
}

#Preview("Код") {
    EmailBindingView().environmentObject(
        previewStore(.codeEntry(email: "new@example.com", isChange: true, error: .invalidCode(remainingAttempts: 2)),
                     email: "anna@example.com")
    )
}

#Preview("Готово — смена") {
    EmailBindingView().environmentObject(
        previewStore(.done(email: "new@example.com", changed: true, previousNotified: true),
                     email: "anna@example.com")
    )
}
