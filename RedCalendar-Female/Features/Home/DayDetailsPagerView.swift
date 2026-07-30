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
    @Binding var height: CGFloat

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

    init(
        dayStamp: Daystamp,
        width: CGFloat,
        dragOffset: Binding<CGFloat>,
        height: Binding<CGFloat>
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
                    dragOffset: day == activeDay ? dragOffset : 0
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
            // Only a card that is still the selected one is re-evaluated, so this is the
            // moment a day committed by a swipe becomes the one the calendar should follow.
            if cardFrame != .zero {
                height = cardFrame.height
            }

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
        }
        .onPreferenceChange(DayCardFrameKey.self) { frame in
            guard frame != .zero else { return }
            cardFrame = frame

            // A card closed while another is opened keeps reporting all the way through its
            // exit animation. Its day is no longer the selected one, and the calendar must
            // not centre on a card that is leaving.
            guard store.state.calendarState.selectedDayStamp == dayStamp else { return }
            // `.move` changes the reported origin on every frame of the entrance while the
            // height stays put, so this fires ~60 times with the same value — and it writes
            // into HomeView's state, rebuilding the calendar with it.
            if height != frame.height {
                height = frame.height
            }
        }
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
            velocity: velocity
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
        }
    }

    private func handleDragChanged(translation: CGFloat) {
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
            return
        }

        let pulledFarEnough = dragOffset > restingHeight * dismissHeightFraction

        if (pulledFarEnough && velocity >= -150) || velocity > velocityThreshold {
            store.send(.setSelectedDayStamp(nil))
        } else {
            withAnimation(.cardEntrance) {
                dragOffset = 0
            }
        }
    }
}
