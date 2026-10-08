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
        // The sign-out that ends either one waits for the server's answer, up to a request
        // timeout, and the screen it was asked from would otherwise sit there unchanged for all
        // of it — reading as a request that never took. The data is already wiped by then, so
        // nothing behind this screen is left to show anyway.
        if let sessionEnding = store.state.sessionEnding {
            WaitingView(sessionEnding == .deletion ? "DeleteAccount.Waiting.Message" : "SignOut.Waiting.Message")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("AppBackgroundColor"))
        } else if let authState = store.state.authState {
            switch authState {
            case .notAuthenticated, .authenticating(_):
                WelcomeView()
            case .authenticated(_, let isFreshRegistration):
                if isFreshRegistration {
                    CycleOnboardingView()
                } else if let version = store.state.consent.required {
                    ConsentPromptView(version: version)
                } else {
                    HomeView()
                }
            // The consent step comes before the migration, which is a sign-in like any other (SYNC.md
            // §21.4), and has no way out: the 2.0 id stays in the keychain until the migration
            // succeeds or finds the account deleted, so an interrupted launch lands back on this step.
            case .migrating(let userId, nil) where store.state.consent.signInVersion == nil:
                SignInConsentView { version in
                    store.send(.consent(.agreeForSignIn(version: version)))
                    store.send(.auth(.set(.migrating(userId: userId, error: nil))))
                }
                .background(Color("AppBackgroundColor"))
            // The one migration failure a retry cannot fix. The legacy id is already gone from the
            // keychain, so the way out is the welcome screen, where a new account can be made.
            case .migrating(_, .accountDeleted(let message)?):
                migrationFailure(
                    icon: Image(systemName: "person.crop.circle.badge.xmark").foregroundColor(.secondary),
                    heading: "Migration.AccountDeleted.Heading",
                    message: Text(message).font(.body).foregroundColor(.secondary),
                    button: "Migration.AccountDeleted.Button"
                ) {
                    store.send(.auth(.set(.notAuthenticated)))
                }
            case .migrating(let userId, let migrationError?):
                migrationFailure(
                    icon: Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange),
                    heading: "Migration.Failed.Heading",
                    message: Text(migrationError.localizedDescription).font(.caption).foregroundColor(.red),
                    button: "Common.Retry"
                ) {
                    store.send(.auth(.set(.migrating(userId: userId, error: nil))))
                }
            case .migrating:
                migrationScreen {
                    ProgressView("Migration.Progress.Title")

                    Text("Migration.Progress.Subtitle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else {
            WaitingView("Migration.CheckingAuth")
        }
    }

    // MARK: - Private Methods

    private func migrationFailure<Icon: View>(
        icon: Icon,
        heading: LocalizedStringKey,
        message: Text,
        button: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        migrationScreen {
            icon
                .font(.system(size: 40))
                .padding(.bottom, 8)

            Text(heading)
                .font(.headline)
                .foregroundColor(.primary)

            message
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(button, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 16)
        }
    }

    private func migrationScreen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 16, content: content)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("AppBackgroundColor"))
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
