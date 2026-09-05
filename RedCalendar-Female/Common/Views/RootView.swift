//
//  RootView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        if let authState = store.state.authState {
            switch authState {
            case .notAuthenticated, .authenticating(_):
                WelcomeView()
            case .authenticated(_, let isFreshRegistration):
                if isFreshRegistration {
                    CycleOnboardingView()
                } else {
                    HomeView()
                }
            case .migrating(let userId, let migrationError):
                VStack(spacing: 16) {
                    if let migrationError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                            .padding(.bottom, 8)
                        
                        Text("Migration.Failed.Heading")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(migrationError.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Common.Retry") {
                            store.send(.auth(.set(.migrating(userId: userId, error: nil))))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 16)
                    } else {
                        ProgressView("Migration.Progress.Title")
                        
                        Text("Migration.Progress.Subtitle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("AppBackgroundColor"))
            }
        } else {
            WaitingView("Migration.CheckingAuth")
        }
    }
}

#Preview {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(),
                reducer: appReducer,
                middlewares: combineAppMiddlewares()
            )
        )
}

#Preview("Migration Error") {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(),
                reducer: appReducer,
                middlewares: combineAppMiddlewares()
            )
        )
}
