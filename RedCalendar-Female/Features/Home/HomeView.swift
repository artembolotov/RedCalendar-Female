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
    // Written by CalendarView, which is what knows the screen and the chrome band; read by the
    // pager, which is what has to keep the card under it. See `CalendarView.resolvedMaxCardHeight`.
    @State private var maxDayCardHeight: CGFloat = .infinity
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
                            scrollCommand: $scrollCommand,
                            maxCardHeight: $maxDayCardHeight,
                            // Read here and handed down, because here is the last place it
                            // can be read: a reader inside a view that has already escaped
                            // the safe area has none left to report and hands back zero.
                            topInset: geometry.safeAreaInsets.top
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
                                    height: $dayCardHeight,
                                    maxHeight: maxDayCardHeight
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
                    // bottom of the calendar. The calendar's top band draws its own slice of
                    // the same value, so it is shared rather than written out here.
                    .background(
                        LinearGradient.appBackground
                            .ignoresSafeArea()
                    )
                    .onChange(of: store.state.calendarState.selectedDayStamp) { newValue in
                        if newValue == nil {
                            dragOffset = 0
                            dayCardHeight = .none
                            detailsPresentation += 1
                        }
                    }
                    // On the stack, never on the reader around it. A `GeometryReader` that
                    // ignores the safe area itself has none left to describe and reports zero
                    // insets — which collapses the calendar's top band onto the status bar and
                    // puts the weekday labels next to the clock. The reader honours the safe
                    // area so it can measure it; the content is what escapes it.
                    .ignoresSafeArea(edges: [.top, .bottom])
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            SyncIndicatorView(
                                syncState: store.state.syncState,
                                accent: store.state.accentTheme.accent
                            )
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HomeMenuView(accent: store.state.accentTheme.accent)
                        }
                    }
                    // Otherwise the bar's own background sits on top of the calendar's band
                    // and there is nothing left to see through.
                    .transparentNavigationBarBackground()
                }
                // On the reader, and only the keyboard — which is the exception to the note
                // above, not a contradiction of it. That note is about the *device* insets: the
                // reader has to honour those, because reading `safeAreaInsets.top` off it is
                // where the calendar's whole top band comes from. The keyboard is a different
                // region, and the reader has no business honouring it.
                //
                // The calendar is sized by this reader and centres the selected week on half
                // that height. Keyboard avoidance shrinks the reader whenever a text field has
                // focus — the comment editor's, presented over this screen — and the calendar
                // then takes the shortened screen for the screen, lifting every week by half of
                // what the keyboard took. Nothing else moves with it, which is what makes it so
                // hard to read as a height problem: the top band is pinned to the top of the
                // screen, and the week height is already at its 50pt floor on both sides of the
                // change, so the rows do not even re-space. The only symptom is a calendar that
                // has stopped centring.
                //
                // `.ignoresSafeArea(edges: [.top, .bottom])` on the stack inside does not cover
                // this. It defaults to every region, keyboard included, but it can only make
                // *that stack* escape an inset — it cannot give back height the reader above it
                // was never proposed.
                .ignoresSafeArea(.keyboard)
                // Presented from state rather than from a one-shot trigger, and here rather than
                // on the sheet that caused it. A comment is saved as its sheet is dismissing, so
                // the failure arrives while a presentation is already in flight and an alert
                // asked for at that moment can be dropped. Driven by a binding over state it
                // cannot be: the flag stays true until the user answers, so SwiftUI presents it
                // on the first pass where it is able to.
                .alert(
                    "Не удалось сохранить",
                    isPresented: writeFailurePresented,
                    presenting: store.state.calendarState.writeFailure
                ) { _ in
                    // No action of its own — dismissal goes through the binding below, so there
                    // is one path that clears the failure rather than two that both have to.
                    Button("Понятно", role: .cancel) {}
                } message: { failure in
                    Text(failure.failureMessage)
                }
            }
        }
    }

    private var writeFailurePresented: Binding<Bool> {
        Binding(
            get: { store.state.calendarState.writeFailure != nil },
            set: { isPresented in
                guard !isPresented else { return }
                store.send(.data(.dismissWriteFailure))
            }
        )
    }

    private func setTodaySelected() {
        store.send(.calendar(.selectDay(store.state.calendarState.todayDayStamp)))
    }
}

#Preview {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "B7DDU4pUigTiAhpNDWnQW83tGQ6R")
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
