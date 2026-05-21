//
//  EmailEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct EmailEntryView: View {
    @EnvironmentObject var store: AppStore
    
    @State private var emailText: String = ""
    @FocusState private var isEmailFieldFocused: Bool
    
    private var isEmailValid: Bool {
        emailText.trimmingCharacters(in: .whitespacesAndNewlines).isValidEmail
    }
    
    private func continueAction() {
        let trimmedEmail = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedEmail.isValidEmail else { return }
        
        isEmailFieldFocused = false
        store.send(.setAuthState(.authenticating(.email(.checking(email: trimmedEmail, name: nil)))))
    }
    
    var body: some View {
        
        if let authState = store.state.authState,
           case .authenticating(.email(.entry(let email, let error))) = authState {
            
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
                            TextField("Email", text: $emailText)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .submitLabel(.continue)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($isEmailFieldFocused)
                                .onSubmit {
                                    continueAction()
                                }
                                .formFieldStyle()
                            
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
                        
                       Group {
                           Text("Пользователи RedCalendar 2.0\nмогут войти [по номеру телефона](phone)")
                                     
                           if error != nil {
                               Text("Нужна помощь?\n [support@calendar.red](email)")
                           }
                       }
                       .font(.caption)
                       .foregroundColor(.secondary)
                       .multilineTextAlignment(.center)
                       .environment(\.openURL, OpenURLAction { url in
                           switch url.absoluteString {
                           case "phone": store.send(.setAuthState(.authenticating(.phone(.entry()))))
                           case "email": UIApplication.shared.open(URL(string: "mailto:support@calendar.red")!)
                           default: break
                           }
                           return .handled
                       })
                        
                    }
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                    .padding(.horizontal)
                    .onAppear {
                        setupInitialState(email: email)
                    }
                }
            }
            .navigationTitle("Вход")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func setupInitialState(email: String?) {
        
        emailText = email ?? ""
        
        Task { @MainActor in
            isEmailFieldFocused = true
        }
    }
}

#Preview {
    EmailEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticating(.email(.entry(
                        email: nil,
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("With pre-filled email") {
    EmailEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticating(.email(.entry(
                        email: "user@example.com",
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("With error") {
    EmailEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticating(.email(.entry(
                        email: "invalid@email",
                        error: AuthenticationError.emailAlreadyExists
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
