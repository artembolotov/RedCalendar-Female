//
//  LoginView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationView {
            Group {
                if let authState = store.state.authState,
                   case .authenticating(let method) = authState {
                    // First, and again if the text changes under a sign-in (SYNC.md §21.4). Phone
                    // is reached from inside this sheet, so this one step covers both ways in.
                    if store.state.consent.signInVersion == nil {
                        SignInConsentView { version in
                            // Read before agreeing, which clears it.
                            let retry = store.state.consent.signInRetry
                            store.send(.consent(.agreeForSignIn(version: version)))
                            if let retry {
                                store.send(.auth(.set(retry)))
                            }
                        }
                    } else {
                        switch method {
                        case .email(let emailState):
                            emailAuthView(for: emailState)
                        case .phone(let phoneState):
                            phoneAuthView(for: phoneState)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Common.Cancel") {
                        store.send(.auth(.set(.notAuthenticated)))
                    }
                }
            }
        }
    }
    
    // MARK: - Email Auth Views
    @ViewBuilder
    private func emailAuthView(for state: EmailAuthState) -> some View {
        switch state {
        
        case .entry(_, _):
            EmailEntryView()
        case .checking(_, _):
            WaitingView("SignIn.Waiting.SendingCode")
        case .codeEntry(_, _, _, _), .registration(_, _, _, _):
            CodeEntryView()
        case .verifying(_, _, _):
            WaitingView("SignIn.Waiting.CheckingCode")
        case .registering(_, _, _):
            WaitingView("SignIn.Waiting.CreatingAccount")
        }
    }
    
    // MARK: - Phone Auth Views
    @ViewBuilder
    private func phoneAuthView(for state: PhoneAuthState) -> some View {
        switch state {
        case .entry(_, _):
            PhoneEntryView()
        case .requesting(_, _):
            WaitingView("SignIn.Waiting.CheckingPhone")
        case .verification(_, _, _, _, _, _):
            FlashCallCodeEntryView()
        case .verifying(_, _, _, _, _):
            WaitingView("SignIn.Waiting.CheckingCode")
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(
            AppStore(
                initialState: AppState(authState: .authenticating(.email(.entry()))),
                reducer: appReducer,
                middlewares: []
            )
        )
}
