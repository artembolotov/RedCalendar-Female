//
//  RegistrationView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 20.06.2025.
//

import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var store: AppStore
    
    let email: String
    let code: String?
    let error: AuthenticationError?
    
    @State private var name: String = ""
    @State private var codeInput: String = ""
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case name
        case code
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        codeInput.count == 6 &&
        codeInput.allSatisfy { $0.isNumber }
    }
    
    init(email: String, code: String? = nil, error: AuthenticationError? = nil) {
        self.email = email
        self.code = code
        self.error = error
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 12) {
                        Text("Регистрация")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Введите ваше имя и код из письма, отправленного на \(email)")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Form fields
                    VStack(spacing: 16) {
                        
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Имя")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            TextField("Введите ваше имя", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocorrectionDisabled()
                                .textContentType(.name)
                                .focused($focusedField, equals: .name)
                                .onSubmit {
                                    focusedField = .code
                                }
                        }
                        
                        // Code field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Код из письма")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            TextField("000000", text: $codeInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
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
                                        continueAction()
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
                    
                    // Continue button
                    PrimaryButton(
                        "Продолжить",
                        isEnabled: isFormValid,
                        action: continueAction
                    )
                    
                    Spacer(minLength: 50)
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Регистрация")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Focus on name field when view appears
            focusedField = .name
            // Pre-fill code if provided
            if let code = code {
                codeInput = code
            }
        }
    }
    
    private func continueAction() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.send(.setAuthState(.authenticating(.email(.registering(
            email: email,
            code: codeInput,
            name: trimmedName
        )))))
    }
}

#Preview {
    RegistrationView(
        email: "test@example.com",
        code: "123456"
    )
    .environmentObject(
        AppStore(
            initialState: AppState(
                apnsToken: nil,
                authState: .authenticating(.email(.registration(
                    email: "test@example.com",
                    code: "123456",
                    error: nil
                )))
            ),
            reducer: appReducer,
            middlewares: []
        )
    )
}
