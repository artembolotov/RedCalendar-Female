//
//  HomeView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var dayDetailsHeight: CGFloat = 0
    @State private var floatingButtonState: FloatingButtonState = .plus
    @State private var scrollCommand: ScrollCommand = .none
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        NavigationView {
            if case .authenticated(_, _, let calendarState) = store.state.authState {
                GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        CalendarView(
                            prefferedBottomOffset: $dayDetailsHeight,
                            floatingButtonState: $floatingButtonState,
                            scrollCommand: $scrollCommand
                        )
                        
                        if let dayStamp = calendarState.selectedDayStamp {
                            DayDetailsView(
                                dayStamp: dayStamp,
                                dragOffset: $dragOffset  // Pass dragOffset binding
                            )
                            .id(dayStamp.rawValue)
                            .transition(.move(edge: .bottom))
                            .zIndex(1)
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
                    .onChange(of: calendarState.selectedDayStamp) { newValue in
                        if newValue == nil {
                            dragOffset = 0
                        }
                    }
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
