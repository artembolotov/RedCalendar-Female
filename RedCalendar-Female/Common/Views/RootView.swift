//
//  ContentView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        switch store.state.authCheckState {
        case .checking:
            ProgressView("Проверка авторизации...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
        case .authenticated:
            HomeView()
        case .notAuthenticated:
            LoginView()
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
