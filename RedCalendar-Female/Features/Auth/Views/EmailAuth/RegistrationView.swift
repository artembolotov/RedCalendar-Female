//
//  RegistrationView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Registration")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Регистрация нового пользователя")
                .foregroundColor(.primary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Регистрация")
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
                        step: .userDataEntry
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
