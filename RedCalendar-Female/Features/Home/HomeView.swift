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
    @State private var dayDetailsDisplayId = UUID()
    
    var body: some View {
        NavigationView {
            if case .authenticated(_, _, let calendarState) = store.state.authState {
                GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        CalendarView(
                            bottomCenterOffset: $bottomCenterOffset,
                            floatingButtonState: $floatingButtonState,
                            scrollCommand: $scrollCommand
                        )
                        
                        if let dayStamp = calendarState.selectedDayStamp {
                            DayDetailsView(dayStamp: dayStamp)
                                .padding(.horizontal)
                                .transition(.move(edge: .bottom))
                                .zIndex(1)
                                .id(dayDetailsDisplayId)
                        } else {
                            FloatingAddButton(
                                state: floatingButtonState,
                                scrollCommand: $scrollCommand,
                                onPlusTapped: setTodaySelected
                            )
                            .padding(.leading, 20)
                            .padding(.bottom, 20)
                            .transition(.scale)
                        }
                    }
                    .animation(.bouncy, value: calendarState.selectedDayStamp != nil)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HomeMenuView()
                        }
                    }
                }
            }
        }
    }
    
    private func setTodaySelected() {
        let dayStamp = Daystamp.today(calendar: Calendar.current)
        resetDayDetailsDisplayId()
        
        store.send(.setSelectedDayStamp(dayStamp))
    }
    
    private func resetDayDetailsDisplayId() {
        dayDetailsDisplayId = UUID()
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
