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
        case .authenticating(.email(.codeEntry(let email, let code, let name, let error))):
            buildView(email: email, name: name, code: code, error: error, isRegistration: false)

        case .authenticating(.email(.registration(let email, let code, let name, let error))):
            buildView(email: email, name: name, code: code, error: error, isRegistration: true)
            
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func buildView(
        email: String,
        name: String? = nil,
        code: String? = nil,
        error: AuthenticationError?,
        isRegistration: Bool
    ) -> some View {
        let codeValid = codeInput.count == 6 && codeInput.allSatisfy { $0.isNumber }

        let isFormValid = codeValid
        
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Back button in top-left corner of content
                    HStack {
                        Button(action: { goBackToWelcome(email: email) }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.accent)
                        }
                        .offset(x: -10)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    if !isRegistration {
                        greeting(name: name)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text(String.localized("EmailCode.Sent.Message", email))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if isRegistration {
                        TextField("EmailCode.Name.Placeholder", text: $nameInput)
                            .textContentType(.name)
                            .submitLabel(.next)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .name)
                            .onSubmit {
                                focusedField = .code
                            }
                            .formFieldStyle()
                    }
                    
                    TextField("EmailCode.Code.Placeholder", text: $codeInput)
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
                                submitAction(
                                    email: email,
                                    isRegistration: isRegistration,
                                    name: name
                                )
                            }
                        }
                        .formFieldStyle()
                    
                    if let error = error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("EmailCode.Resend.Footer")
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
                        isRegistration ? "EmailCode.Submit.Register" : "EmailCode.Submit.SignIn",
                        isEnabled: isFormValid,
                        accent: store.state.accentTheme.accent,
                        action: { submitAction(
                            email: email,
                            isRegistration: isRegistration,
                            name: name
                        ) }
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
        .navigationTitle(isRegistration ? "EmailCode.Register.Title" : "EmailCode.SignIn.Title")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Private Views

    private func greeting(name: String?) -> Text {
        if let name, !name.isEmpty {
            return Text(String.localized("EmailCode.Greeting.Named", name))
        }
        return Text("EmailCode.Greeting.Returning")
    }

    // MARK: - Actions
    
    private func goBackToWelcome(email: String) {
        // Return to email entry screen with current email preserved
        store.send(.auth(.set(.authenticating(.email(.entry(
            email: email,
            error: nil
        ))))))
    }
    
    private func setupInitialState(code: String?, name: String?, isRegistration: Bool) {
        
        nameInput = name ?? ""
        codeInput = code ?? ""
        
        focusedField = (isRegistration && (name == nil || nameInput.isEmpty)) ? .name : .code
    }
    
    private func submitAction(email: String, isRegistration: Bool, name: String?) {
        if isRegistration {
            let trimmedName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            store.send(.auth(.set(.authenticating(.email(.registering(
                email: email,
                code: codeInput,
                name: trimmedName.isEmpty ? nil : trimmedName
            ))))))
        } else {
            store.send(.auth(.set(.authenticating(.email(.verifying(
                email: email,
                code: codeInput,
                name: name
            ))))))
        }
    }
    
    private func resendCodeAction(email: String, isRegistration: Bool) {
        if isRegistration {
            let trimmedName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameToPreserve = trimmedName.isEmpty ? nil : trimmedName
            store.send(.auth(.set(.authenticating(.email(.checking(email: email, name: nameToPreserve))))))
        } else {
            store.send(.auth(.set(.authenticating(.email(.checking(email: email, name: nil))))))
        }
    }
}

#Preview("Code Entry - with name") {
    CodeEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
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
