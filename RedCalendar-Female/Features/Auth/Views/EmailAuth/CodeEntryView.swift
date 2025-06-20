//
//  EnterCodeView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 20.06.2025.
//

import SwiftUI

struct CodeEntryView: View {
    @EnvironmentObject var store: AppStore
    
    let email: String
    let userName: String?
    let error: AuthenticationError?
    
    @State private var code: String = ""
    @FocusState private var isCodeFieldFocused: Bool
    
    private var isFormValid: Bool {
        code.count == 6 && code.allSatisfy { $0.isNumber }
    }
    
    private var greetingText: String {
        if let userName = userName, !userName.isEmpty {
            return "Привет, \(userName)!"
        } else {
            return "С возвращением!"
        }
    }
    
    private var instructionText: String {
        return "Введите код из письма для входа в аккаунт"
    }
    
    init(email: String, userName: String? = nil, error: AuthenticationError? = nil) {
        self.email = email
        self.userName = userName
        self.error = error
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    
                    // Header section
                    VStack(spacing: 16) {
                        Text(greetingText)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            Text(instructionText)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("Письмо отправлено на \(email)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Code input section
                    VStack(spacing: 16) {
                        
                        // Code field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Код из письма")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            TextField("000000", text: $code)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .focused($isCodeFieldFocused)
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .onChange(of: code) { newValue in
                                    // Limit to 6 digits and numbers only
                                    let filtered = String(newValue.prefix(6).filter { $0.isNumber })
                                    if filtered != newValue {
                                        code = filtered
                                    }
                                }
                                .onSubmit {
                                    if isFormValid {
                                        submitAction()
                                    }
                                }
                        }
                        
                        // Error message
                        if let error = error {
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Login button
                    PrimaryButton(
                        "Войти",
                        isEnabled: isFormValid,
                        action: submitAction
                    )
                    
                    // Resend section
                    VStack(spacing: 12) {
                        Text("Не получили код?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Отправить повторно") {
                            resendCodeAction()
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                    
                    Spacer(minLength: 50)
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Вход")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Auto focus on code field when view appears
            isCodeFieldFocused = true
        }
    }
    
    private func submitAction() {
        store.send(.setAuthState(.authenticating(.email(.verifying(
            email: email,
            code: code
        )))))
    }
    
    private func resendCodeAction() {
        // Go back to checking state to resend code
        store.send(.setAuthState(.authenticating(.email(.checking(email: email)))))
    }
}

#Preview("User with name") {
    CodeEntryView(
        email: "anna@example.com",
        userName: "Анна"
    )
    .environmentObject(
        AppStore(
            initialState: AppState(
                apnsToken: nil,
                authState: .authenticating(.email(.codeEntry(
                    email: "anna@example.com",
                    userName: "Анна",
                    error: nil
                )))
            ),
            reducer: appReducer,
            middlewares: []
        )
    )
}

#Preview("User without name") {
    CodeEntryView(
        email: "user@example.com",
        userName: nil
    )
    .environmentObject(
        AppStore(
            initialState: AppState(
                apnsToken: nil,
                authState: .authenticating(.email(.codeEntry(
                    email: "user@example.com",
                    userName: nil,
                    error: nil
                )))
            ),
            reducer: appReducer,
            middlewares: []
        )
    )
}
