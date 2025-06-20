//
//  UserDataEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 19.06.2025.
//

import SwiftUI

struct UserDataEntryView: View {
    let email: String
    @EnvironmentObject var store: AppStore
    
    @State private var name: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case name, password, confirmPassword
    }
    
    init(email: String) {
        self.email = email
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Text(email)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Name field
                        TextField("Имя", text: $name)
                            .keyboardType(.default)
                            .textContentType(.name)
                            .submitLabel(.next)
                            .autocapitalization(.words)
                            .disableAutocorrection(false)
                            .focused($focusedField, equals: .name)
                            .onSubmit {
                                focusedField = .password
                            }
                            .formFieldStyle()
                        
                        // Small spacing after name field
                        Spacer()
                            .frame(height: 8)
                        
                        // Password field
                        SecureField("Пароль (минимум 6 символов)", text: $password)
                            .textContentType(.newPassword)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                focusedField = .confirmPassword
                            }
                            .formFieldStyle()
                        
                        // Confirm password field
                        SecureField("Подтвердите пароль", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .confirmPassword)
                            .onSubmit {
                                if isFormValid {
                                    continueAction()
                                }
                            }
                            .formFieldStyle()
                        
                        // Validation messages
                        VStack(alignment: .leading, spacing: 4) {
                            if !password.isEmpty && password.count < 6 {
                                Text("Пароль должен содержать минимум 6 символов")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            
                            if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Пароли не совпадают")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Continue button
                    PrimaryButton(
                        "Продолжить",
                        isEnabled: isFormValid,
                        action: continueAction
                    )
                    
                    // No resend button needed anymore
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
        }
    }
    
    private func continueAction() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.send(.setAuthState(.authenticating(.email(.registration(
            email: email,
            step: .creating(name: trimmedName, password: password)
        )))))
    }
}

#Preview {
    UserDataEntryView(email: "test@example.com")
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.registration(
                        email: "test@example.com",
                        step: .userDataEntry
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
