//
//  UnifiedCodeEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 20.06.2025.
//

import SwiftUI

struct CodeEntryView: View {
    @EnvironmentObject var store: AppStore
    
    @State private var nameInput: String = ""
    @State private var codeInput: String = ""
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case name
        case code
    }
    
    var body: some View {
        switch store.state.authState {
        case .authenticating(.email(.codeEntry(let email, let userName, let error))):
            buildView(email: email, userName: userName, error: error, isRegistration: false)
            
        case .authenticating(.email(.registration(let email, let code, let name, let error))):
            buildView(email: email, code: code, name: name, error: error, isRegistration: true)
            
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func buildView(
        email: String,
        userName: String? = nil,
        code: String? = nil,
        name: String? = nil,
        error: AuthenticationError?,
        isRegistration: Bool
    ) -> some View {
        let codeValid = codeInput.count == 6 && codeInput.allSatisfy { $0.isNumber }
        let nameValid = !nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isFormValid = isRegistration ? (nameValid && codeValid) : codeValid
        
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    
                    if !isRegistration {
                        Text(userName?.isEmpty == false ? "Привет, \(userName!)!" : "С возвращением!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Text("Код для входа отправлен на \(email)")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if isRegistration {
                        TextField("Ваше имя", text: $nameInput)
                            .textContentType(.name)
                            .submitLabel(.next)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .name)
                            .onSubmit {
                                focusedField = .code
                            }
                            .formFieldStyle()
                    }
                    
                    TextField("Код из письма", text: $codeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .submitLabel(.continue)
                        .focused($focusedField, equals: .code)
                        .onChange(of: codeInput) { newValue in
                            let filtered = String(newValue.prefix(6).filter { $0.isNumber })
                            if filtered != newValue {
                                codeInput = filtered
                            }
                        }
                        .onSubmit {
                            if isFormValid {
                                submitAction(email: email, isRegistration: isRegistration)
                            }
                        }
                        .formFieldStyle()
                    
                    if let error = error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("Не получили письмо?\n[Отправить повторно](resend)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .environment(\.openURL, OpenURLAction { url in
                            if url.absoluteString == "resend" {
                                resendCodeAction(email: email, isRegistration: isRegistration)
                            }
                            return .handled
                        })
                    
                    PrimaryButton(
                        isRegistration ? "Продолжить" : "Войти",
                        isEnabled: isFormValid,
                        action: { submitAction(email: email, isRegistration: isRegistration) }
                    )
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal)
                .onAppear {
                    setupInitialState(code: code, name: name, isRegistration: isRegistration)
                }
            }
        }
        .navigationTitle(isRegistration ? "Регистрация" : "Вход")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func setupInitialState(code: String?, name: String?, isRegistration: Bool) {
        if let name = name {
            nameInput = name
        }
        if let code = code {
            codeInput = code
        }
        
        if isRegistration {
            if name != nil && !nameInput.isEmpty {
                focusedField = .code
            } else {
                focusedField = .name
            }
        } else {
            focusedField = .code
        }
    }
    
    private func submitAction(email: String, isRegistration: Bool) {
        if isRegistration {
            let trimmedName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            store.send(.setAuthState(.authenticating(.email(.registering(
                email: email,
                code: codeInput,
                name: trimmedName
            )))))
        } else {
            store.send(.setAuthState(.authenticating(.email(.verifying(
                email: email,
                code: codeInput
            )))))
        }
    }
    
    private func resendCodeAction(email: String, isRegistration: Bool) {
        if isRegistration {
            let trimmedName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameToPreserve = trimmedName.isEmpty ? nil : trimmedName
            store.send(.setAuthState(.authenticating(.email(.checking(email: email, name: nameToPreserve)))))
        } else {
            store.send(.setAuthState(.authenticating(.email(.checking(email: email, name: nil)))))
        }
    }
}

#Preview("Code Entry - with name") {
    CodeEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.codeEntry(
                        email: "arina@example.com",
                        userName: "Арина",
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("Code Entry - without name") {
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

#Preview("Registration - empty") {
    CodeEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.registration(
                        email: "test@example.com",
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

#Preview("Registration - with pre-filled name") {
    CodeEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.registration(
                        email: "user@example.com",
                        code: "123456",
                        name: "Арина",
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
