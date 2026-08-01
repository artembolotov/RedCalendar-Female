//
//  HomeView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var dayCardHeight: DayCardHeight = .none
    @State private var floatingButtonState: FloatingButtonState = .plus
    @State private var scrollCommand: ScrollCommand = .none
    @State private var dragOffset: CGFloat = 0
    // Bumped every time the card closes, so the next one is a new view rather than the one
    // still on its way out.
    @State private var detailsPresentation = 0
    
    var body: some View {
        NavigationView {
            if store.state.isAuthenticated {
                GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        CalendarView(
                            cardHeight: $dayCardHeight,
                            floatingButtonState: $floatingButtonState,
                            scrollCommand: $scrollCommand
                        )

                        // The spring covers only the card/button pair: a transaction opened
                        // over the calendar would animate the grid's own scroll offset on the
                        // frame of the tap, against the display link already driving it.
                        ZStack(alignment: .bottomLeading) {
                            if let dayStamp = store.state.calendarState.selectedDayStamp {
                                DayDetailsPagerView(
                                    dayStamp: dayStamp,
                                    width: geometry.size.width,
                                    dragOffset: $dragOffset,
                                    height: $dayCardHeight
                                )
                                // Reopening while the previous card is still transitioning out
                                // would revive that one, and a revived view keeps the position it
                                // had rather than sliding in.
                                .id(detailsPresentation)
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
                        // Without this the inner stack shrinks to the card and takes the
                        // bottom alignment with it — the outer one is sized by the calendar.
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .animation(.cardEntrance, value: store.state.calendarState.selectedDayStamp != nil)
                    }
                    .background(Color("AppBackgroundColor").ignoresSafeArea())
                    .onChange(of: store.state.calendarState.selectedDayStamp) { newValue in
                        if newValue == nil {
                            dragOffset = 0
                            dayCardHeight = .none
                            detailsPresentation += 1
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
        store.send(.setSelectedDayStamp(store.state.calendarState.todayDayStamp))
    }
}

#Preview {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(
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
