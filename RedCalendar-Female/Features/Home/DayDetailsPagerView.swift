//
//  DayDetailsPagerView.swift
//  RedCalendar-Female
//

import SwiftUI

// Horizontal pager around `DayDetailsView`: dragging the card sideways moves the selection
// one day at a time, dragging it down dismisses it. Both come from the same window pan
// recognizer, which decides the axis once per gesture.
//
// Cards are laid out against `anchor` and moved by a single offset that `CardPagingAnimator`
// drives frame by frame. Because that offset can always be read, re-basing (`reanchor()`)
// works at any moment — it moves the anchor and the offset by the same slot, which draws
// exactly the same pixels — so a swipe can take the card over mid-settle without a jump.
struct DayDetailsPagerView: View {
    @EnvironmentObject var store: AppStore

    let dayStamp: Daystamp
    let width: CGFloat

    @Binding var dragOffset: CGFloat
    // The height the calendar centres against, published for the day it belongs to — see
    // `DayCardHeight`. Every path that settles what height a day's card stands at writes it.
    @Binding var height: DayCardHeight

    @StateObject private var animator = CardPagingAnimator()

    // The visual state leads the store: `Store.send` lands a run loop later, so paging has to
    // be driven locally and let the selection catch up. The anchor is therefore seeded once,
    // in `init`, and never derived from `dayStamp` — see the note there.
    @State private var anchor: Daystamp
    @State private var shiftInFlight = 0
    @State private var cardFrame: CGRect = .zero
    @State private var isPaging = false
    @State private var isDraggingHorizontally = false
    // Offset the current drag started from, so the card follows the finger from wherever it
    // was rather than from wherever the last gesture left the model.
    @State private var dragStartOffset: CGFloat = 0
    // Day we last dispatched. Two quick swipes put two selections in flight, and the first
    // one arriving back must not drag the pager backwards.
    @State private var pendingSelection: Daystamp?

    // The level: the height every mounted card is drawn at, whatever its own content asks for.
    // A day arriving by swipe or by tap inherits the level of the one before it and only moves
    // to its own once it has stayed put — see `scheduleLevelSettle()`. `nil` until the first
    // card of an opening has been measured.
    @State private var levelHeight: CGFloat?
    @State private var naturalHeight: CGFloat = 0
    // The day the level currently belongs to, so a card standing at its own height keeps
    // following its content while one that merely inherited a level does not.
    @State private var settledDay: Daystamp?
    // A day picked in the calendar rather than paged to: it takes its own height on the first
    // measurement instead of standing out the dwell. Held as a day and not a flag because a day
    // whose height matches the level changes no preference and so is never collected — a flag
    // would stay raised and hand the next swipe the wrong behaviour.
    @State private var immediateLevelDay: Daystamp?
    @State private var levelSettleTask: Task<Void, Never>?

    private let velocityThreshold: CGFloat = 1200
    private let rubberBandFactor: CGFloat = 0.3
    // How much of its own height the card has to be pulled down by to close. A share rather
    // than a distance: the card is sized by its content, so days differ by hundreds of points
    // and any fixed number would be past a short card's whole height.
    private let dismissHeightFraction: CGFloat = 0.35
    private let maxUpwardOffset: CGFloat = 150

    private let pageCommitRatio: CGFloat = 0.25
    // Share of a slot the finger moves one-to-one before the drag starts resisting.
    private let dragFreeRatio: CGFloat = 0.85
    // How far ahead a flick is projected when deciding whether it committed a page.
    private let pageVelocityProjection: CGFloat = 0.15
    // The spring covers most of this in its first third — the rest is the tail settling, in
    // the same shape the calendar's own scroll animation uses.
    private let settleDuration: TimeInterval = 0.55
    private let settleDamping: Double = 0.85
    // How long a card has to stand still before it is allowed to leave the level it inherited.
    // Timed from the moment the card arrives — not from the end of the settle's curve, which
    // runs on well past that — so a run of quick swipes never reaches it and every day in that
    // run is drawn at the same level.
    //
    // What the number is measured against is the settle's own residual wobble: at
    // `settleDuration` and `settleDamping` the card is within 0.5pt of its slot at 0.21s (a
    // flick) to 0.27s (a slow release), and its overshoot falls under 2pt at 0.34–0.36s
    // whatever speed it left at. So this lands the height change on the first moment the card
    // is genuinely still, and the user waits ~0.4s from lifting their finger — inside the
    // window where the resize still reads as the tail of their own gesture rather than as
    // something the card decided on its own.
    //
    // That budget is also the whole of what the dwell has to cover. The next swipe cancels it
    // at its first `.changed`, which in a run of 2–3 swipes a second arrives 0.2–0.33s after
    // the previous lift — before this fires. A pause long enough to reach it is a pause the
    // user is reading in, and there the day's own height is worth more than a stable one.
    //
    // Growing and shrinking once waited different amounts, on the grounds that a card holding
    // a level too short clips rows while one holding a level too tall only carries blank space.
    // That distinction was worth 300ms when the waits were 0.3s and 0.6s and the resize landed
    // either inside the gesture or well outside it. At this length both directions are inside
    // it, and the moment the card stops moving does not depend on which way its content goes.
    private let levelDwellDelay: TimeInterval = 0.15

    init(
        dayStamp: Daystamp,
        width: CGFloat,
        dragOffset: Binding<CGFloat>,
        height: Binding<DayCardHeight>
    ) {
        self.dayStamp = dayStamp
        self.width = width
        self._dragOffset = dragOffset
        self._height = height
        // Fixed when the card opens. The anchor must not follow `dayStamp`: that moves under
        // the pager exactly when the store catches up with a page the pager has already
        // committed, which would carry `activeDay` a further day along with it.
        self._anchor = State(initialValue: dayStamp)
    }

    private var activeDay: Daystamp {
        anchor + shiftInFlight
    }

    // The gap between two cards equals the card's own inset from the screen edge, so the
    // next card begins exactly where the screen ends and never shows an edge at rest.
    private var pageStride: CGFloat {
        width - DayDetailsMetrics.screenInset
    }

    // Neighbours are only mounted while paging — parked at the screen edge their shadow
    // would bleed back over it.
    private var visibleDays: [Daystamp] {
        isPaging ? [anchor - 1, anchor, anchor + 1] : [activeDay]
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(visibleDays, id: \.rawValue) { day in
                DayDetailsView(
                    dayStamp: day,
                    isActive: day == activeDay,
                    dragOffset: day == activeDay ? dragOffset : 0,
                    levelHeight: levelHeight
                )
                .offset(x: CGFloat(day - anchor) * pageStride + animator.offset)
            }
        }
        .background(
            WindowGestureHandler(gestureFrame: cardFrame) { translation, velocity, state, axis in
                handlePan(translation: translation, velocity: velocity, state: state, axis: axis)
            }
        )
        .onChange(of: dayStamp) { newValue in
            // While our own selection is still in flight the store is behind us; only a day
            // that came from somewhere else (a calendar tap) re-centers the pager.
            if let pending = pendingSelection {
                if newValue == pending {
                    pendingSelection = nil
                }
                return
            }

            guard newValue != activeDay else { return }
            anchor = newValue
            shiftInFlight = 0
            isPaging = false
            animator.setOffset(0)
            // Reachable only while nothing of ours is in flight, so this day was chosen in the
            // calendar. Picking a date is never a run of dates: there is nothing to hold a
            // borrowed level for, and the card takes its own as soon as it is measured.
            immediateLevelDay = newValue
        }
        .onChange(of: activeDay) { newValue in
            // The level belonged to the day we just left. `reanchor()` moves `anchor` and
            // `shiftInFlight` together, so it does not reach this.
            cancelLevelSettle()
            settledDay = nil

            if immediateLevelDay != newValue {
                immediateLevelDay = nil
            }

            // A day chosen in the calendar is not waiting on anything.
            guard immediateLevelDay == nil else { return }

            // This day is keeping the level it inherited, so its card's height is already
            // known and the calendar has nothing to wait for. A day chosen in the calendar
            // returns above instead: its own height arrives with the next measurement, and
            // publishing the level it is about to leave would send the calendar to the wrong
            // place first.
            if let level = levelHeight {
                publish(level, for: newValue)
            }

            // A swipe arrives mid-settle, and is armed by that settle's arrival — arming here
            // would only be cancelled by the next frame of it. Everything else is already at
            // rest by now.
            if !isPaging && !isDraggingHorizontally {
                scheduleLevelSettle()
            }
        }
        .onPreferenceChange(DayCardFrameKey.self) { frame in
            // Only the gesture geometry comes from here — the calendar's height is written
            // from the level, which is a value this view already knows and changes once per
            // transition rather than once per frame of one.
            guard frame != .zero else { return }
            cardFrame = frame
        }
        .onPreferenceChange(DayCardNaturalHeightKey.self) { measurement in
            // A downward drag shortens the card, and the measurement shortens with it — that
            // is the drag, not the day's own height. A measurement from a card that is no
            // longer the active one belongs to the day being left.
            guard measurement.height > 0, measurement.day == activeDay, dragOffset == 0 else { return }
            let measured = measurement.height
            naturalHeight = measured

            if levelHeight == nil {
                // The first card of an opening has no level to inherit.
                applyLevel(measured, animated: false)
            } else if immediateLevelDay == activeDay {
                immediateLevelDay = nil
                applyLevel(measured, animated: true)
            } else if settledDay == activeDay {
                // Already standing at its own height, so it keeps following its content:
                // adding a comment or a tag resizes it there and then, as it always has.
                applyLevel(measured, animated: false)
            }
        }
        .onDisappear {
            cancelLevelSettle()
        }
    }

    // MARK: - Level

    private func applyLevel(_ newHeight: CGFloat, animated: Bool) {
        guard newHeight > 0 else { return }
        // A card closed while another is opened lives on through its exit animation, and its
        // dwell can still be pending; only the pager showing the selected day may write the
        // height the calendar centres against. The store trails `activeDay` for a run loop
        // after a swipe commits, but nothing applies a level inside that window.
        guard store.state.calendarState.selectedDayStamp == activeDay else { return }

        // Recorded before the early exit below: a day whose own height happens to equal the
        // level it inherited is still standing at its own, and has to keep following its
        // content from here on.
        settledDay = activeDay

        // Published before that exit as well: the number may be unchanged while the day it
        // belongs to is not, and the calendar is waiting on the day.
        publish(newHeight, for: activeDay)

        guard levelHeight != newHeight else { return }

        // Deferred a run loop turn: `applyLevel` is called from
        // `onPreferenceChange(DayCardNaturalHeightKey.self)`, and `levelHeight` feeds
        // `drawnBoxHeight`, which is what `DayCardFrameKey`'s own GeometryReader measures.
        // Writing it synchronously here re-resolves that preference inside the same update
        // SwiftUI is still processing — "Bound preference DayCardFrameKey tried to update
        // multiple times per frame". One tick costs nothing visible; the fix has to move the
        // write out of the preference callback that's still on the stack.
        if animated {
            Task { @MainActor in
                withAnimation(.cardLevelChange) {
                    levelHeight = newHeight
                }
            }
        } else {
            Task { @MainActor in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    levelHeight = newHeight
                }
            }
        }
    }

    /// Hands a day's card height to the calendar, which centres the day in the space above it.
    ///
    /// Outside any animation: this lands in HomeView's state and feeds the calendar's own
    /// spring, which must not be re-driven frame by frame from here. One write per level
    /// change is one flight there.
    private func publish(_ newHeight: CGFloat, for day: Daystamp) {
        let published = DayCardHeight(day: day, height: newHeight)
        guard height != published else { return }

        var plain = Transaction()
        plain.disablesAnimations = true
        withTransaction(plain) {
            height = published
        }
    }

    // Armed where the card comes to rest, so the level never moves under a finger or midway
    // through a settle.
    private func scheduleLevelSettle() {
        cancelLevelSettle()

        let day = activeDay
        levelSettleTask = Task { @MainActor in
            guard await sleepUnlessCancelled(levelDwellDelay), isResting(on: day) else { return }
            applyLevel(naturalHeight, animated: true)
        }
    }

    private func sleepUnlessCancelled(_ delay: TimeInterval) async -> Bool {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return !Task.isCancelled
    }

    private func isResting(on day: Daystamp) -> Bool {
        day == activeDay && !isDraggingHorizontally && dragOffset == 0
    }

    private func cancelLevelSettle() {
        // The vertical drag calls this on every frame; without the guard each one would be a
        // state write, and the card is already rebuilding on the drag offset alone.
        guard let task = levelSettleTask else { return }
        task.cancel()
        levelSettleTask = nil
    }

    // MARK: - Gesture routing

    private func handlePan(translation: CGFloat, velocity: CGFloat, state: PanGestureState, axis: PanGestureAxis) {
        switch axis {
        case .vertical:
            handleVerticalPan(translation: translation, velocity: velocity, state: state)
        case .horizontal:
            handleHorizontalPan(translation: translation, velocity: velocity, state: state)
        }
    }

    // MARK: - Horizontal paging

    private func handleHorizontalPan(translation: CGFloat, velocity: CGFloat, state: PanGestureState) {
        switch state {
        case .began:
            break

        case .changed:
            let start: CGFloat

            if isDraggingHorizontally {
                start = dragStartOffset
            } else {
                isDraggingHorizontally = true
                isPaging = true
                cancelLevelSettle()
                // Take the card over exactly where the settle had got to, and rebase onto the
                // day the user is actually looking at.
                animator.cancel()
                reanchor()
                // The pan is already a few points along by the time its axis is settled;
                // anchoring to that keeps the first frame of the drag from stepping.
                start = animator.offset - translation
                dragStartOffset = start
            }

            animator.setOffset(resisted(start + translation))

        case .ended:
            isDraggingHorizontally = false

            // Measured from the anchor rather than from the drag, so a card taken over
            // half-way to the next day is judged on where it actually sits.
            let projected = animator.offset + velocity * pageVelocityProjection
            let commitDistance = pageStride * pageCommitRatio

            // Dragging left brings in the card on the right — the next day.
            if projected < -commitDistance {
                commit(shift: 1, velocity: velocity)
            } else if projected > commitDistance {
                commit(shift: -1, velocity: velocity)
            } else {
                settle(to: 0, velocity: velocity)
            }

        case .cancelled, .failed:
            isDraggingHorizontally = false
            settle(to: 0, velocity: 0)
        }
    }

    // A gesture moves the card by at most one day, and only the two neighbours are mounted —
    // so past most of a slot the drag stiffens and comes to rest at exactly one, instead of
    // pulling an unmounted third card's empty space onto the screen.
    private func resisted(_ offset: CGFloat) -> CGFloat {
        let limit = pageStride
        let free = limit * dragFreeRatio
        let magnitude = abs(offset)

        guard magnitude > free else { return offset }

        let remaining = limit - free
        let overshoot = magnitude - free
        let damped = remaining * (1 - 1 / (overshoot / remaining + 1))

        return (offset < 0 ? -1 : 1) * (free + damped)
    }

    private func commit(shift: Int, velocity: CGFloat) {
        // Read off the anchor before settling: a settle with nothing left to travel finishes
        // synchronously, and its completion re-anchors.
        let newSelection = anchor + shift

        shiftInFlight = shift
        settle(to: CGFloat(-shift) * pageStride, velocity: velocity)

        pendingSelection = newSelection
        store.send(.setSelectedDayStamp(newSelection))
    }

    private func settle(to target: CGFloat, velocity: CGFloat) {
        animator.animate(
            to: target,
            duration: settleDuration,
            damping: settleDamping,
            velocity: velocity,
            // The card has stopped: from here it either stays long enough to take its own
            // height, or the next swipe cancels the dwell and it keeps this level. Timed
            // against arrival rather than the completion below, which waits out a tail of the
            // curve that is far too small to see — the dwell would read as twice its length.
            onArrival: { scheduleLevelSettle() }
        ) {
            reanchor()
            isPaging = false
        }
    }

    // Moves the slot the offsets are measured from and the offset itself by the same page,
    // which draws exactly the same pixels — so this is safe at any point in a settle.
    private func reanchor() {
        guard shiftInFlight != 0 else { return }

        let newAnchor = activeDay
        let compensated = animator.offset + CGFloat(shiftInFlight) * pageStride

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            anchor = newAnchor
            shiftInFlight = 0
            animator.setOffset(compensated)
        }
    }

    // MARK: - Vertical dismiss

    private func handleVerticalPan(translation: CGFloat, velocity: CGFloat, state: PanGestureState) {
        switch state {
        case .began:
            break
        case .changed:
            handleDragChanged(translation: translation)
        case .ended:
            handleDragEnded(velocity: velocity)
        case .cancelled, .failed:
            withAnimation(.cardEntrance) {
                dragOffset = 0
            }
            scheduleLevelSettle()
        }
    }

    private func handleDragChanged(translation: CGFloat) {
        // The card is being resized by the finger; a level change on top of that would fight it.
        cancelLevelSettle()

        if translation < 0 {
            let absTranslation = abs(translation)
            let initialVisualThreshold = maxUpwardOffset / 3
            let initialTranslationThreshold = initialVisualThreshold / rubberBandFactor

            if absTranslation <= initialTranslationThreshold {
                dragOffset = translation * rubberBandFactor
            } else {
                let baseOffset = initialVisualThreshold
                let excessTranslation = absTranslation - initialTranslationThreshold

                let remainingDistance = maxUpwardOffset - initialVisualThreshold
                let resistanceFactor = 1.0 / (1.0 + excessTranslation / (remainingDistance * 2.0))
                let excessOffset = excessTranslation * rubberBandFactor * resistanceFactor

                let totalOffset = baseOffset + excessOffset
                dragOffset = -min(totalOffset, maxUpwardOffset)
            }
        } else {
            dragOffset = translation
        }
    }

    private func handleDragEnded(velocity: CGFloat) {
        // Dragging down by d shortens the card by exactly d, so the measured frame plus the
        // drag gives back the height the card rests at — no separate state for it.
        let restingHeight = cardFrame.height + dragOffset

        guard restingHeight > 0 else {
            withAnimation(.cardEntrance) { dragOffset = 0 }
            scheduleLevelSettle()
            return
        }

        let pulledFarEnough = dragOffset > restingHeight * dismissHeightFraction

        if (pulledFarEnough && velocity >= -150) || velocity > velocityThreshold {
            cancelLevelSettle()
            store.send(.setSelectedDayStamp(nil))
        } else {
            withAnimation(.cardEntrance) {
                dragOffset = 0
            }
            scheduleLevelSettle()
        }
    }
}
