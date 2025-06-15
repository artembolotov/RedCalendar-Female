//
//  PasswordVerifyingView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct PasswordVerifyingView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Password Verifying")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Проверяем пароль...")
                .foregroundColor(.white.opacity(0.8))
            
            // Temporary test button
            Button("→ Success (Authenticated)") {
                store.send(.setAuthState(.authenticated(
                    deviceId: "test_device_id_123",
                    userDetails: UserDetails(userId: "test_user_id")
                )))
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red)
        .navigationTitle("Проверка пароля")
    }
}

#Preview {
    PasswordVerifyingView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.passwordVerifying(
                        email: "test@example.com",
                        password: "password123"
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
