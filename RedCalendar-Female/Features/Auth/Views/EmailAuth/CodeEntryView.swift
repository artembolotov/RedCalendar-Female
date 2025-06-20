//
//  CodeEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 20.06.2025.
//

import SwiftUI

struct CodeEntryView: View {
    @EnvironmentObject var store: AppStore
    
    @State private var code: String = ""
    @FocusState private var isCodeFieldFocused: Bool
    
    private var isFormValid: Bool {
        code.count == 6 && code.allSatisfy { $0.isNumber }
    }
    
    var body: some View {
        // Direct access to store state
        if let authState = store.state.authState,
           case .authenticating(.email(.codeEntry(let email, let userName, let error))) = authState {
            
            let greetingText = {
                if let userName = userName, !userName.isEmpty {
                    return "Привет, \(userName)!"
                } else {
                    return "С возвращением!"
                }
            }()
            
            let instructionText = "Введите код из письма для входа в аккаунт"
            
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
                                            submitAction(email: email)
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
                            action: { submitAction(email: email) }
                        )
                        
                        // Resend section
                        VStack(spacing: 12) {
                            Text("Не получили код?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Отправить повторно") {
                                resendCodeAction(email: email)
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
                    .onAppear {
                        // Auto focus on code field when view appears
                        isCodeFieldFocused = true
                    }
                }
            }
            .navigationTitle("Вход")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func submitAction(email: String) {
        store.send(.setAuthState(.authenticating(.email(.verifying(
            email: email,
            code: code
        )))))
    }
    
    private func resendCodeAction(email: String) {
        // Go back to checking state to resend code
        store.send(.setAuthState(.authenticating(.email(.checking(email: email, name: nil)))))
    }
}

#Preview("User with name") {
    CodeEntryView()
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
    CodeEntryView()
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

#Preview("With error") {
    CodeEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.codeEntry(
                        email: "user@example.com",
                        userName: "Анна",
                        error: AuthenticationError.invalidVerificationCode
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
