//
//  HomeView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var bottomCenterOffset: CGFloat = 0
    @State private var floatingButtonState: FloatingButtonState = .plus
    @State private var scrollCommand: ScrollCommand = .none
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                if case .authenticated(_, _, let calendarState) = store.state.authState {
                    
                    CalendarView(
                        bottomCenterOffset: $bottomCenterOffset,
                        floatingButtonState: $floatingButtonState,
                        scrollCommand: $scrollCommand
                    )
                    .ignoresSafeArea(edges: .bottom)
                    
                    FloatingAddButton(
                        state: floatingButtonState,
                        scrollCommand: $scrollCommand,
                        onPlusTapped: setTodaySelected
                    )
                    .padding(.leading, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .ignoresSafeArea(edges: .bottom)
                    
                    if calendarState.selectedDayStamp != nil {
                        DayDetailsView()
                            .ignoresSafeArea(edges: .bottom)
                    }
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
    
    private func setTodaySelected() {
        let dayStamp = Daystamp.today(calendar: Calendar.current)
        store.send(.setSelectedDayStamp(dayStamp))
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
                        userDetails: nil,
                        calendarState: CalendarState()
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
