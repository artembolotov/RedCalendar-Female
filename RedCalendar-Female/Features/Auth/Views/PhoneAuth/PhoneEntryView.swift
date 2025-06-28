//
//  PhoneEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 16.06.2025.
//

import SwiftUI
import PhoneNumberKit

struct PhoneEntryView: View {
    @EnvironmentObject var store: AppStore
    
    @State private var phoneText: String = ""
    @State private var e164PhoneNumber: String? = nil

    private var isPhoneValid: Bool {
        e164PhoneNumber != nil
    }
    
    private func continueAction() {
        guard let validE164Number = e164PhoneNumber else { return }
        
        store.send(.setAuthState(.authenticating(.phone(.requesting(phoneNumber: validE164Number)))))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    
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
                        PhoneNumberKitField(
                            phoneNumber: $phoneText,
                            e164PhoneNumber: $e164PhoneNumber,
                            onSubmit: continueAction
                        )
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        
                        PrimaryButton(isEnabled: isPhoneValid, action: continueAction) {
                            Image(systemName: "arrow.right")
                                .font(.title3)
                        }
                        .frame(width: 56, height: 56)
                    }
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal)
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
}

#Preview {
    PhoneEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.phone(.entry()))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
