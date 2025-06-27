//
//  PhoneEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 16.06.2025.
//

import SwiftUI

struct PhoneEntryView: View {
    @EnvironmentObject var store: AppStore
    
    @State private var phoneText: String = ""
    @FocusState private var isPhoneFieldFocused: Bool
    
    // Phone validation computed property
    private var isPhoneValid: Bool {
        let phoneRegex = #"^\+7\d{10}$"#
        return NSPredicate(format: "SELF MATCHES %@", phoneRegex).evaluate(with: phoneText)
    }
    
    // Continue action
    private func continueAction() {
        guard isPhoneValid else { return }
        isPhoneFieldFocused = false
        store.send(.setAuthState(.authenticating(.phone(.requesting(phoneNumber: phoneText)))))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Back button in top-left corner of content
                    HStack {
                        Button(action: { goBackToEmail() }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .offset(x: -10)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    Text("Вход по номеру")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Мы позвоним на указанный номер для подтверждения входа в приложение.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Phone input with inline arrow button
                    HStack(spacing: 12) {
                        TextField("+7", text: $phoneText)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .submitLabel(.continue)
                            .focused($isPhoneFieldFocused)
                            .onSubmit {
                                continueAction()
                            }
                            .formFieldStyle()
                        
                        // Arrow button using custom PrimaryButton
                        PrimaryButton(isEnabled: isPhoneValid, action: continueAction) {
                            Image(systemName: "arrow.right")
                                .font(.title3)
                        }
                        .frame(width: 56)
                    }
                    
                    Text("Нужна помощь?\n [support@calendar.red](email)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .environment(\.openURL, OpenURLAction { url in
                        if url.absoluteString == "email" {
                            UIApplication.shared.open(URL(string: "mailto:support@calendar.red")!)
                        }
                        return .handled
                    })
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal)
                .onAppear {
                    setupInitialState()
                }
            }
        }
        .navigationTitle("Вход")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Actions
    
    private func goBackToEmail() {
        // Return to email entry screen
        store.send(.setAuthState(.authenticating(.email(.entry(
            email: nil,
            error: nil
        )))))
    }
    
    private func setupInitialState() {
        Task { @MainActor in
            isPhoneFieldFocused = true
        }
    }
}

#Preview {
    PhoneEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.phone(.entry))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
