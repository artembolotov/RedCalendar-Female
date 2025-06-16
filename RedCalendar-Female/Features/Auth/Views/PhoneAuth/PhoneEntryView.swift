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
        store.send(.setAuthState(.authenticating(.phone(.requesting(phoneNumber: phoneText)))))
    }
    
    var body: some View {
        ZStack {
            // Main content centered vertically
            VStack(spacing: 20) {
                Text("Добро пожаловать!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    Text("Введите номер телефона")
                        .foregroundColor(.secondary)
                    
                    Text("Только для пользователей RedCalendar 2.0")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                // Phone input field
                TextField("+7", text: $phoneText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($isPhoneFieldFocused)
                    .onAppear {
                        // Set focus when view appears
                        Task { @MainActor in
                            isPhoneFieldFocused = true
                        }
                    }
                
                // Continue button
                Button("Продолжить") {
                    continueAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isPhoneValid)
            }
            .frame(maxWidth: 320) // Ограничение ширины
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
            
            // Email login button overlay - positioned at top leading
            VStack {
                HStack {
                    Button("Вход по почте") {
                        store.send(.setAuthState(.authenticating(.email(.entry()))))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Вход")
        .navigationBarTitleDisplayMode(.inline)
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
