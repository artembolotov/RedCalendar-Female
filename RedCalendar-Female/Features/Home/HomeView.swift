//
//  HomeView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var floatingButtonState: FloatingButtonState = .plus
    @State private var bottomCenterOffset: CGFloat = 0
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                if store.state.isAuthenticated {
                    CalendarView(
                        bottomCenterOffset: $bottomCenterOffset,
                        floatingButtonState: $floatingButtonState
                    )
                    .ignoresSafeArea(edges: .bottom)
                    
                    FloatingAddButton(state: floatingButtonState)
                        .padding(.leading, 20)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HomeMenuView()
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticated(
                        deviceId: "B7DDU4pUigTiAhpNDWnQW83tGQ6R",
                        userDetails: nil
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
