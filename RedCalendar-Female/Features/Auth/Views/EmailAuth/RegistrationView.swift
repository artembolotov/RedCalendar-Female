//
//  RegistrationView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 20.06.2025.
//

import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var store: AppStore
    
    @State private var nameInput: String = ""
    @State private var codeInput: String = ""
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case name
        case code
    }
    
    private var isFormValid: Bool {
        !nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        codeInput.count == 6 &&
        codeInput.allSatisfy { $0.isNumber }
    }
    
    var body: some View {
        // Direct access to store state
        if let authState = store.state.authState,
           case .authenticating(.email(.registration(let email, let code, let name, let error))) = authState {
            
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        
                        Text("Введите ваше имя и код из письма, отправленный на \(email)")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Name input
                        TextField("Ваше имя", text: $nameInput)
                            .textContentType(.name)
                            .submitLabel(.next)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .name)
                            .onSubmit {
                                focusedField = .code
                            }
                            .formFieldStyle()
                        
                        // Code input
                        TextField("Код из письма", text: $codeInput)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .submitLabel(.continue)
                            .focused($focusedField, equals: .code)
                            .onChange(of: codeInput) { newValue in
                                // Limit to 6 digits and numbers only
                                let filtered = String(newValue.prefix(6).filter { $0.isNumber })
                                if filtered != newValue {
                                    codeInput = filtered
                                }
                            }
                            .onSubmit {
                                if isFormValid {
                                    continueAction(email: email)
                                }
                            }
                            .formFieldStyle()
                        
                        // Error message
                        if let error = error {
                            Text(error.localizedDescription)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("Не получили письмо?\n[Отправить повторно](resend)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .environment(\.openURL, OpenURLAction { url in
                                if url.absoluteString == "resend" {
                                    resendCodeAction(email: email)
                                }
                                return .handled
                            })
                        
                        // Continue button
                        PrimaryButton(
                            "Продолжить",
                            isEnabled: isFormValid,
                            action: { continueAction(email: email) }
                        )
                    }
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                    .padding(.horizontal)
                    .onAppear {
                        setupInitialState(code: code, name: name)
                    }
                }
            }
            .navigationTitle("Регистрация")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func setupInitialState(code: String?, name: String?) {
        // Pre-fill name if provided
        if let name = name {
            nameInput = name
        }
        // Pre-fill code if provided
        if let code = code {
            codeInput = code
        }
        // Focus logic: if name is pre-filled, focus on code, otherwise on name
        if name != nil && !nameInput.isEmpty {
            focusedField = .code
        } else {
            focusedField = .name
        }
    }
    
    private func continueAction(email: String) {
        let trimmedName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        store.send(.setAuthState(.authenticating(.email(.registering(
            email: email,
            code: codeInput,
            name: trimmedName
        )))))
    }
    
    private func resendCodeAction(email: String) {
        store.send(.setAuthState(.authenticating(.email(.checking(email: email, name: nameInput)))))
    }
}

#Preview {
    RegistrationView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.registration(
                        email: "test@example.com",
                        code: "123456",
                        name: nil,
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("Without pre-filled code") {
    RegistrationView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.registration(
                        email: "user@example.com",
                        code: nil,
                        name: nil,
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("With pre-filled name") {
    RegistrationView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.registration(
                        email: "user@example.com",
                        code: nil,
                        name: "Анна",
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("With error") {
    RegistrationView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.registration(
                        email: "test@example.com",
                        code: "123456",
                        name: "Анна",
                        error: AuthenticationError.invalidVerificationCode
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
