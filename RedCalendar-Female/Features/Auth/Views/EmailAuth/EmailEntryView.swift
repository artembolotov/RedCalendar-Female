//
//  EmailEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct EmailEntryView: View {
    @EnvironmentObject var store: AppStore
    
    let email: String?
    let error: Error?
    
    @State private var emailText: String = ""
    @FocusState private var isEmailFieldFocused: Bool
    
    private var isEmailValid: Bool {
        emailText.contains("@") && emailText.contains(".") && emailText.count > 5
    }
    
    private func continueAction() {
        guard isEmailValid else { return }
        store.send(.setAuthState(.authenticating(.email(.checking(email: emailText)))))
    }
    
    init(email: String? = nil, error: Error? = nil) {
        self.email = email
        self.error = error
    }
    
    var body: some View {
        // Main content centered vertically
        VStack(spacing: 20) {
            Text("Добро пожаловать!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Данные хранятся на устройстве и в облаке. Email нужен для доступа к вашему профилю")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Email input field
            TextField("Email", text: $emailText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.continue)
                .focused($isEmailFieldFocused)
                .onAppear {
                    if let email = email { emailText = email }
                    Task { @MainActor in isEmailFieldFocused = true }
                }
                .onSubmit {
                    continueAction()
                }
            
            // Error display
            if let error = error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            // Continue button
            Button("Продолжить") {
                continueAction()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isEmailValid)
            
            // Alternative login info
            Text("Пользователи RedCalendar 2.0\nмогут войти [по номеру телефона](phone)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .environment(\.openURL, OpenURLAction { url in
                    if url.absoluteString == "phone" {
                        store.send(.setAuthState(.authenticating(.phone(.entry))))
                    }
                    return .handled
                })
        }
        .frame(maxWidth: 320) // Ограничение ширины
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal)
        .navigationTitle("Вход")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    EmailEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.entry()))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
