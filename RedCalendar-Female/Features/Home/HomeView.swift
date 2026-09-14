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
    // Written by `SyncIndicatorView`, read here to drive `.sharedBackgroundVisibility` on its
    // `ToolbarItem` — see that binding's doc for why the badge can't do this to itself.
    @State private var syncIndicatorVisible = false
    // Whether a day card has been built in this process yet — see `cardWarmUp(width:)`.
    @State private var isCardWarmedUp = false

    var body: some View {
        NavigationView {
            if store.state.isAuthenticated {
                GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        if !isCardWarmedUp, maxDayCardHeight.isFinite, store.state.calendarState.selectedDayStamp == nil {
                            cardWarmUp(width: geometry.size.width)
                        }

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
                        } else if !isCardWarmedUp {
                            // A real card has now paid what the warm-up exists to pay, so a
                            // warm-up still waiting for its turn has nothing left to do — and
                            // must not mount later, in the middle of this card's exit.
                            isCardWarmedUp = true
                        }
                    }
                    // On the stack, never on the reader around it. A `GeometryReader` that
                    // ignores the safe area itself has none left to describe and reports zero
                    // insets — which collapses the calendar's top band onto the status bar and
                    // puts the weekday labels next to the clock. The reader honours the safe
                    // area so it can measure it; the content is what escapes it.
                    .ignoresSafeArea(edges: [.top, .bottom])
                    .navigationBarTitleDisplayMode(.inline)
                    .modifier(HomeToolbar(
                        syncState: store.state.syncState,
                        accent: store.state.accentTheme.accent,
                        onRetry: { store.send(.sync(.requested(.retry))) },
                        syncIndicatorVisible: $syncIndicatorVisible
                    ))
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
                    "Home.WriteFailure.Title",
                    isPresented: writeFailurePresented,
                    presenting: store.state.calendarState.writeFailure
                ) { _ in
                    // No action of its own — dismissal goes through the binding below, so there
                    // is one path that clears the failure rather than two that both have to.
                    Button("Common.GotIt", role: .cancel) {}
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

    /// The day card, built once while nothing is animating and thrown away a run loop later.
    ///
    /// The first card of a process costs several times what every later one does: the view
    /// graph for the pager and the card is instantiated from cold, and that one-off cost lands in
    /// the frame the card starts sliding in on. Measured on the simulator in a Debug build, the
    /// first opening spent 56–96ms before the card could be measured and dropped a 73–138ms frame;
    /// a second opening of the same day took 15ms. Built here first, the first opening measures
    /// at ~21ms and its longest frame is ~31ms — the same as any later one. Nothing is kept: what
    /// warms is the runtime's and SwiftUI's per-type caches, which outlive the view.
    ///
    /// The whole pager rather than the card alone, because the pager's own cold cost was a third
    /// of what was left once the card had been warmed. It is inert here by construction: its
    /// height is written only while its day is the selected one (`applyLevel`), which the guard
    /// at its use makes impossible — the warm-up mounts only while nothing is selected. Its window
    /// pan is installed and removed within that run loop, and `WindowGestureHandler.Coordinator`
    /// clears `current` only if it is still the one that set it.
    ///
    /// Launch is where it goes because launch is the one moment nothing is moving: mounted later
    /// it would take the same frame out of a scroll instead. But not the *first* pass of launch,
    /// which is why the guard at its use also waits for `maxDayCardHeight` — the one value
    /// `CalendarView` writes once it has built its calculator. Mounted alongside the calendar's
    /// first pass, it left the calendar set up against a width of about a hundred points that no
    /// later pass corrected — seven columns squeezed against the leading edge, for as long as the
    /// app ran. Most likely the warm-up's weight moved which pass the calendar's `GeometryReader`
    /// first reported on, and the calendar's own setup already says it cannot count on that (see
    /// the `onAppear` beside its `onChange(of: metrics)`). Not proven; what is observed is that
    /// waiting one pass keeps launch exactly as it was without the warm-up.
    private func cardWarmUp(width: CGFloat) -> some View {
        DayDetailsPagerView(
            dayStamp: store.state.calendarState.todayDayStamp,
            width: width,
            dragOffset: .constant(0),
            height: .constant(.none),
            maxHeight: maxDayCardHeight
        )
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            Task { @MainActor in
                isCardWarmedUp = true
            }
        }
    }

    private func setTodaySelected() {
        store.send(.calendar(.selectDay(store.state.calendarState.todayDayStamp)))
    }
}

/// `.sharedBackgroundVisibility` (iOS 26+) is a `ToolbarContent` modifier, not a `View` one, so
/// hiding it below 26 can't be an inline `if #available` inside `.toolbar {}` the way it can be
/// almost everywhere else in this app: `ToolbarContentBuilder`'s `buildEither` — what an `if`
/// with an `else` compiles down to — only exists from iOS 16, four versions above this app's 15.4
/// floor, while plain `ViewBuilder`'s has been there since iOS 13. Branching a `ViewModifier`
/// instead of the `.toolbar {}` call itself is what buys back the `if #available … else` this app
/// otherwise takes for granted — CLAUDE.md's `#available` guidance is about *which* fix a warning
/// needs, not a promise that every `if #available` compiles at this floor regardless of which
/// builder it sits in.
///
/// Without `.sharedBackgroundVisibility(.hidden)` at `.idle`, the system's own "Liquid Glass"
/// background behind this toolbar item stays visible — an empty glass circle — because that
/// background is keyed off whether the item has content at all, not off what that content
/// currently renders as, so `SyncIndicatorView`'s own `.opacity(0)` never reaches it. See
/// `syncIndicatorVisible` on `HomeView`.
private struct HomeToolbar: ViewModifier {
    let syncState: SyncState
    let accent: Color
    let onRetry: () -> Void
    @Binding var syncIndicatorVisible: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SyncIndicatorView(
                        syncState: syncState,
                        accent: accent,
                        onRetry: onRetry,
                        isVisible: $syncIndicatorVisible
                    )
                }
                .sharedBackgroundVisibility(syncIndicatorVisible ? .visible : .hidden)
                ToolbarItem(placement: .navigationBarTrailing) {
                    HomeMenuView(accent: accent)
                }
            }
        } else {
            content.toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SyncIndicatorView(
                        syncState: syncState,
                        accent: accent,
                        onRetry: onRetry,
                        isVisible: $syncIndicatorVisible
                    )
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HomeMenuView(accent: accent)
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
                    authState: .authenticated(deviceId: "B7DDU4pUigTiAhpNDWnQW83tGQ6R")
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
