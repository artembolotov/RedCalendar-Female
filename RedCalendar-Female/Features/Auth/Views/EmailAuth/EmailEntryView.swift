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
        emailText.trimmingCharacters(in: .whitespacesAndNewlines).isValidEmail
    }
    
    private func continueAction() {
        let trimmedEmail = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedEmail.isValidEmail else { return }
        
        isEmailFieldFocused = false
        store.send(.setAuthState(.authenticating(.email(.checking(email: trimmedEmail)))))
    }
    
    init(email: String? = nil, error: Error? = nil) {
        self.email = email
        self.error = error
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    Text("Добро пожаловать!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Данные хранятся на устройстве и в облаке. Email нужен для доступа к вашему профилю")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Email input with inline arrow button
                    HStack(spacing: 12) {
                        CustomTextField(
                            placeholder: "Email",
                            text: $emailText,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            submitLabel: .continue,
                            onSubmit: {
                                continueAction()
                            }
                        )
                        .focused($isEmailFieldFocused)
                        .onAppear {
                            if let email = email { emailText = email }
                            Task { @MainActor in isEmailFieldFocused = true }
                        }
                        
                        // Arrow button using custom PrimaryButton
                        PrimaryButton(isEnabled: isEmailValid, action: continueAction) {
                            Image(systemName: "arrow.right")
                                .font(.title3)
                        }
                        .frame(width: 56)
                    }
                    
                    if let error = error {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    
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
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal)
            }
        }
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
