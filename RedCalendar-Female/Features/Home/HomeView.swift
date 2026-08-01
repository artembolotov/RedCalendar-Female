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
                                    accent: store.state.accentTheme.accent,
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
                    // A very shallow fall in luminance down the screen — enough to stop the
                    // page reading as a flat sheet, small enough that the day indicator's ring
                    // (drawn in the top colour) still disappears into the background at the
                    // bottom of the calendar.
                    .background(
                        LinearGradient(
                            colors: [Color("AppBackgroundColor"), Color("AppBackgroundEdgeColor")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
                    .onChange(of: store.state.calendarState.selectedDayStamp) { newValue in
                        if newValue == nil {
                            dragOffset = 0
                            dayCardHeight = .none
                            detailsPresentation += 1
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HomeMenuView(accent: store.state.accentTheme.accent)
                        }
                    }
                    // Otherwise the bar's own background sits on top of the calendar's band
                    // and there is nothing left to see through.
                    .transparentNavigationBarBackground()
                }
                // On the reader itself, not on the stack inside it. That is what makes
                // `geometry.safeAreaInsets.top` report the inset it stopped honouring — the
                // height of the navigation bar the grid now runs under, which is exactly what
                // `CalendarView` centres against and sizes its top band with.
                .ignoresSafeArea(edges: [.top, .bottom])
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
