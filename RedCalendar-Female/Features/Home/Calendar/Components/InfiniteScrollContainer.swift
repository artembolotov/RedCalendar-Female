//
//  InfiniteScrollContainer.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.08.2025.
//

import SwiftUI

struct InfiniteScrollContainer: UIViewRepresentable {
    @Binding var scrollOffset: CGFloat
    // Read-only: the container acknowledges a command by remembering its id, not by writing
    // the command back.
    let scrollCommand: ScrollCommand


    let onScrollChanged: (CGFloat) -> Void
    let onDragStateChanged: (Bool) -> Void
    let onDayTapped: (Daystamp) -> Void
    let onEmptyAreaTapped: () -> Void
    let initialCenterOffset: CGFloat
    let calculator: MonthCalculator
    let today: Daystamp
    
    private let contentHeight: CGFloat = 8000000
    private let centerY: CGFloat = 4000000
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.contentSize = CGSize(width: 0, height: contentHeight)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.isMultipleTouchEnabled = true
        scrollView.canCancelContentTouches = true
        scrollView.delaysContentTouches = false
        scrollView.backgroundColor = .clear
        scrollView.scrollsToTop = false
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        tapGesture.require(toFail: scrollView.panGestureRecognizer)
        scrollView.addGestureRecognizer(tapGesture)
        
        scrollView.contentOffset.y = centerY - initialCenterOffset
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.updateToday(today)
        context.coordinator.updateCalculator(calculator)
        context.coordinator.updateScrollOffset(scrollOffset)
        
        // The command carries an id rather than being reset to `.none` afterwards: a reset is
        // an extra state write, and a late one would swallow a command issued in between.
        if case .animateToCenter(let id) = scrollCommand,
           id != context.coordinator.lastHandledCommandId {
            context.coordinator.lastHandledCommandId = id

            let targetY = centerY - initialCenterOffset

            // The card's measured height lands a moment after the selection, so a correction
            // usually arrives mid-flight. Bend the flight rather than start it over.
            if context.coordinator.retarget(to: targetY) { return }

            // Close everything past the cap before the animation starts, so the flight only
            // covers the part of the journey a person can follow. See `launchOffset`.
            let launchY = Self.launchOffset(
                from: uiView.contentOffset.y,
                to: targetY,
                viewportHeight: uiView.bounds.height
            )
            if launchY != uiView.contentOffset.y {
                uiView.contentOffset.y = launchY
            }

            // Read back rather than trusting `launchY`: writing the offset runs
            // `scrollViewDidScroll`, which clamps to the rail, and the flight has to be
            // measured from wherever the calendar actually ended up.
            let distance = abs(targetY - uiView.contentOffset.y)

            // Re-selecting the day already centred has nowhere to travel; running the display
            // link over it would still hold the scroll view for the whole duration.
            guard distance > 0.5 else { return }

            let (duration, damping) = Self.spring(forDistance: distance)
            context.coordinator.startAnimation(to: targetY, in: uiView, duration: duration, damping: damping)
            return
        }

        // While the display link drives the offset itself, `scrollOffset` is always a frame
        // behind it — writing it back here would drag the animation backwards every frame.
        // The same is true for the moment between the last frame and the report it scheduled:
        // `isAnimating` is already false there, but `scrollOffset` still holds the older
        // value, and correcting from it would snap the calendar back and then have that stale
        // value written in as the truth. A genuine offset written by SwiftUI moves away from
        // what was last delivered, so it still passes.
        let isStale = context.coordinator.isSyncingOffset
            && abs(scrollOffset - context.coordinator.lastDeliveredOffset) < 1

        if !context.coordinator.isDragging && !context.coordinator.isAnimating && !isStale {
            let targetY = centerY - scrollOffset
            let currentY = uiView.contentOffset.y
            let difference = abs(currentY - targetY)

            if difference > 1 {
                uiView.contentOffset.y = targetY
            }
        }
    }

    /// The only point where a flight in progress can be stopped while the coordinator is still
    /// reachable.
    ///
    /// Its `deinit` cannot do it. A `CADisplayLink` retains its target and the run loop retains
    /// the link until `invalidate()`, so an animating coordinator is held by an object that
    /// outlives the app and is not deallocated at all — the `deinit` is only ever entered with
    /// `displayLink` already nil, where stopping is a no-op. What kept that safe is
    /// `animatingScrollView` being weak: the tick after SwiftUI drops the scroll view finds it
    /// gone and ends the animation itself. But the frames before that still write `contentOffset`
    /// on a detached scroll view, and each write reports a scroll centre that reaches
    /// `DatabaseMiddleware` and re-centres the loaded range on behalf of a view that no longer
    /// exists. Stopping here closes that window rather than waiting for it to close itself.
    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        coordinator.cleanUp()
    }

    /// Damping never decreases with distance: a short hop that overshoots reads as a wobble,
    /// and it is slow enough for the overshoot to be watchable. The short duration also lands
    /// the re-centring together with the card's own entrance.
    ///
    /// The 1400pt threshold is also what `CalendarConstants.flightCapScreens` is chosen
    /// against — the cap decides which of these two curves every long flight gets.
    static func spring(forDistance distance: CGFloat) -> (TimeInterval, Double) {
        distance < 1400 ? (0.5, 0.90) : (0.75, 0.95)
    }

    /// Where the flight actually starts from — the calendar's own position, or the furthest
    /// point from the target it is allowed to fly from.
    ///
    /// Every distance is animated over the same fixed duration, which is fine while the
    /// distance is a screen or two and absurd from the ends of the calendar: the rail is sixty
    /// years away, and covering that in 0.75s is thirteen screens per frame. Nobody reads that
    /// as the calendar travelling — it is a strobe, and it is also the whole of the stutter,
    /// because every reported frame re-anchors the viewport, rebuilds the grid and pushes a
    /// scroll centre that re-centres the loaded range and restarts the database observations
    /// with it. Cutting the journey to `flightCapScreens` cuts all of that to what one flight
    /// across two screens costs.
    ///
    /// The cut is taken on the side the calendar is coming from, so the flight still runs in
    /// the direction the arrow on the button pointed.
    ///
    /// The jump also does the loaded range a favour. It reports a centre a screen or two from
    /// the destination a whole flight before arriving, where the uncapped version only reached
    /// that centre on its final frame — so the days being flown to now have the length of the
    /// animation to arrive from the database, instead of drawing themselves in afterwards.
    static func launchOffset(from current: CGFloat, to target: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        // A view that has not been laid out yet would cap every flight to nothing.
        guard viewportHeight > 0 else { return current }

        let cap = viewportHeight * CalendarConstants.flightCapScreens
        let travel = target - current
        guard abs(travel) > cap else { return current }

        return target - cap * (travel < 0 ? -1 : 1)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let parent: InfiniteScrollContainer
        var isDragging = false
        private var today: Daystamp
        private var calculator: MonthCalculator
        private var currentScrollOffset: CGFloat = 0
        
        // Animation properties
        // `displayLink` and `animatingScrollView` are the two properties `stopAnimation()`
        // touches from `deinit` below, which — alone among every caller here — is not
        // guaranteed to run on the main thread. `nonisolated(unsafe)` lets `stopAnimation()`
        // stay `nonisolated` and callable from there; every other call site is already on the
        // main actor regardless of what the type system requires of it.
        nonisolated(unsafe) private var displayLink: CADisplayLink?
        private var animationStartTime: CFTimeInterval = 0
        private var animationDuration: TimeInterval = 0
        private var animationStartOffset: CGFloat = 0
        private var animationTargetOffset: CGFloat = 0
        private var animationDamping: Double = 0.68
        nonisolated(unsafe) private weak var animatingScrollView: UIScrollView?

        var isAnimating: Bool { displayLink != nil }

        // The last scroll command acted on. Acknowledging by id is what lets the sender leave
        // the command in place instead of writing a reset back.
        var lastHandledCommandId: Int = 0

        // Offset reporting back to SwiftUI
        private var pendingReport: CGFloat?
        private(set) var lastDeliveredOffset: CGFloat = 0

        /// True while an offset has been observed but not yet handed to SwiftUI.
        var isSyncingOffset: Bool { pendingReport != nil }

        init(_ parent: InfiniteScrollContainer) {
            self.parent = parent
            self.today = parent.today
            self.calculator = parent.calculator
        }
        
        // Not the guarantee it looks like: an active `CADisplayLink` is retained by the run loop
        // and retains this coordinator, so `deinit` is unreachable until the link is already gone.
        // `dismantleUIView` is what actually stops a flight. Kept for the case where a coordinator
        // is discarded without its view ever having been dismantled.
        deinit {
            stopAnimation()
        }

        /// Everything that can still reach SwiftUI after the view is gone, dropped in one place.
        ///
        /// Stopping the display link is the visible half. The other half is the report already
        /// scheduled: it is delivered a run loop turn later whatever happens to the view in
        /// between, and delivering it calls `onScrollChanged`, which dispatches a scroll centre
        /// into the store on behalf of a calendar that no longer exists. Clearing `pendingReport`
        /// is enough to stop it — the queued block reads it back and returns when it is gone.
        func cleanUp() {
            stopAnimation()
            pendingReport = nil
        }
        
        func updateToday(_ today: Daystamp) {
            self.today = today
        }
        
        func updateCalculator(_ calc: MonthCalculator) {
            self.calculator = calc
        }
        
        func updateScrollOffset(_ offset: CGFloat) {
            self.currentScrollOffset = offset
        }

        // MARK: - Offset Reporting

        /// Hands the offset to SwiftUI one run loop turn later, coalescing everything the
        /// scroll view observed in between. Both readers take the latest value, so dropping
        /// intermediate ones is free — and `isSyncingOffset` tells `updateUIView` that the
        /// `scrollOffset` it can see is not the truth yet.
        private func report(_ offset: CGFloat) {
            let alreadyScheduled = pendingReport != nil
            pendingReport = offset
            guard !alreadyScheduled else { return }

            DispatchQueue.main.async {
                guard let value = self.pendingReport else { return }
                self.pendingReport = nil
                self.lastDeliveredOffset = value
                self.parent.scrollOffset = value
                self.parent.onScrollChanged(value)
            }
        }

        // MARK: - Animation Methods
        
        func startAnimation(to targetY: CGFloat, in scrollView: UIScrollView, duration: TimeInterval, damping: Double = 0.68) {
            stopAnimation()
            
            // Stop any active scroll/deceleration
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)
            
            animationStartOffset = scrollView.contentOffset.y
            animationTargetOffset = targetY
            animationDuration = duration
            animationDamping = damping
            animationStartTime = CACurrentMediaTime()
            animatingScrollView = scrollView
            
            let link = CADisplayLink(target: self, selector: #selector(updateAnimation))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        
        /// Bends a flight already under way onto a new target instead of restarting it.
        ///
        /// Starting over would re-seed the curve at rest, and the visible result of dropping
        /// the calendar's speed to zero halfway is exactly the stop-and-go this animation is
        /// meant not to have. Rebasing the start so the curve still evaluates to where the
        /// calendar currently is keeps position continuous; only the velocity takes a step,
        /// proportional to how far the target moved.
        ///
        /// - Returns: false when there is nothing to bend or it is too late to bend it, in
        ///   which case the caller should start a fresh animation.
        func retarget(to newTarget: CGFloat) -> Bool {
            guard isAnimating, let scrollView = animatingScrollView else { return false }

            let elapsed = CACurrentMediaTime() - animationStartTime
            let travelled = SpringInterpolation.progress(elapsed / animationDuration, damping: animationDamping)

            // Near the end the rebase divides by almost nothing and the correction would be
            // a jump; let the current flight land and leave the rest to the caller.
            guard travelled < 0.9 else { return false }

            let current = scrollView.contentOffset.y
            animationStartOffset = (current - newTarget * travelled) / (1 - travelled)
            animationTargetOffset = newTarget
            return true
        }

        nonisolated func stopAnimation() {
            displayLink?.invalidate()
            displayLink = nil
            animatingScrollView = nil
        }
        
        @objc private func updateAnimation() {
            guard let scrollView = animatingScrollView else {
                stopAnimation()
                return
            }
            
            let currentTime = CACurrentMediaTime()
            let elapsed = currentTime - animationStartTime
            
            if elapsed >= animationDuration {
                // Animation complete
                scrollView.contentOffset.y = animationTargetOffset
                stopAnimation()
                return
            }
            
            // Spring physics with natural bounce
            let progress = elapsed / animationDuration
            let springProgress = SpringInterpolation.progress(progress, damping: animationDamping)
            
            let delta = animationTargetOffset - animationStartOffset
            let newOffset = animationStartOffset + (delta * springProgress)
            
            scrollView.contentOffset.y = newOffset
        }
        
        // MARK: - Tap Handler
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }

            let tapLocation = gesture.location(in: scrollView)

            // Content-space Y: the scroll view is anchored at centerY, days sit at yPosition
            let tapCalendarY = tapLocation.y - parent.centerY

            if let tappedDay = findDayAt(calendarY: tapCalendarY, tapX: tapLocation.x, scrollView: scrollView) {
                parent.onDayTapped(tappedDay)
            } else {
                parent.onEmptyAreaTapped()
            }
        }

        private func findDayAt(calendarY tapCalendarY: CGFloat, tapX: CGFloat, scrollView: UIScrollView) -> Daystamp? {
            let screenWidth = scrollView.bounds.width
            let screenHeight = scrollView.bounds.height

            // Keep original coordinate system logic
            let dynamicViewport = ViewportCalculator.calculateDynamicViewport(
                scrollOffset: currentScrollOffset,
                screenHeight: screenHeight,
                screenWidth: screenWidth,
                calculator: calculator,
                today: today
            )

            let horizontalPadding = CalendarConstants.horizontalPadding
            let dayWidth = (screenWidth - horizontalPadding) / 7

            // Columns are measured from the grid's own leading edge: cells are drawn from
            // horizontalPadding / 2 (ViewportCalculator.createVisibleMonth), so the padding on
            // either side belongs to no day and reads as free space.
            let gridX = tapX - horizontalPadding / 2
            guard gridX >= 0 else { return nil }

            let dayOfWeek = Int(gridX / dayWidth)
            guard dayOfWeek < 7 else { return nil }

            // Optimize: find month first, then calculate day mathematically
            for month in dynamicViewport.visibleMonths {
                let weeksCount = calculator.getWeeksCount(for: month.monthOffset)

                // Use proper constants instead of magic numbers
                let headerHeight = CalendarConstants.monthHeaderHeight
                let weekSpacing = CalendarConstants.gridVerticalSpacing

                let gridStartY = month.yPosition + headerHeight
                let gridEndY = gridStartY + CGFloat(weeksCount) * (calculator.weekHeight + weekSpacing)

                // The band is the drawn grid and nothing more — the month title and the gap
                // below the last week are free space, and tapping them dismisses the day card.
                // The spacing between two weeks stays with the week above it: a tap a couple of
                // points off should still pick a day rather than dismiss.
                if tapCalendarY >= gridStartY && tapCalendarY < gridEndY {

                    // Calculate which week was tapped using same formula as ViewportCalculator
                    let relativeY = tapCalendarY - gridStartY
                    let weekIndex = Int(relativeY / (calculator.weekHeight + weekSpacing))

                    // Get the specific day directly from month cells array
                    let monthCells = calculator.getMonthCells(for: month.monthOffset)
                    let dayIndex = weekIndex * 7 + dayOfWeek

                    guard dayIndex >= 0 && dayIndex < monthCells.count else { return nil }

                    return monthCells[dayIndex]?.daystamp
                }
            }
            
            return nil
        }
        
        // MARK: - UIGestureRecognizerDelegate
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        // MARK: - UIScrollViewDelegate methods
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let physicalY = scrollView.contentOffset.y
            var calendarOffset = self.parent.centerY - physicalY
            
            let limits = self.calculator.getScrollLimits()
            let originalOffset = calendarOffset
            calendarOffset = max(limits.min, min(limits.max, calendarOffset))
            
            if originalOffset != calendarOffset {
                let correctedPhysicalY = self.parent.centerY - calendarOffset
                scrollView.contentOffset.y = correctedPhysicalY
            }

            report(calendarOffset)
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            // Stop any active animation
            stopAnimation()
            
            isDragging = true
            DispatchQueue.main.async { self.parent.onDragStateChanged(true) }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
            if !willDecelerate {
                isDragging = false
                
                let physicalY = scrollView.contentOffset.y
                var calendarOffset = self.parent.centerY - physicalY
                let limits = self.calculator.getScrollLimits()
                let correctedOffset = max(limits.min, min(limits.max, calendarOffset))
                
                if abs(correctedOffset - calendarOffset) > 0.1 {
                    let correctedPhysicalY = self.parent.centerY - correctedOffset
                    scrollView.contentOffset.y = correctedPhysicalY
                    calendarOffset = correctedOffset
                }
                
                report(calendarOffset)
                DispatchQueue.main.async { self.parent.onDragStateChanged(false) }
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isDragging = false
            
            let physicalY = scrollView.contentOffset.y
            var calendarOffset = self.parent.centerY - physicalY
            let limits = self.calculator.getScrollLimits()
            let correctedOffset = max(limits.min, min(limits.max, calendarOffset))
            
            if abs(correctedOffset - calendarOffset) > 0.1 {
                let correctedPhysicalY = self.parent.centerY - correctedOffset
                scrollView.contentOffset.y = correctedPhysicalY
                calendarOffset = correctedOffset
            }
            
            report(calendarOffset)
            DispatchQueue.main.async { self.parent.onDragStateChanged(false) }
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let targetPhysicalY = targetContentOffset.pointee.y
            let targetCalendarOffset = parent.centerY - targetPhysicalY
            
            let limits = self.calculator.getScrollLimits()
            
            let boundaryBuffer: CGFloat = 200
            let isApproachingTop = targetCalendarOffset > (limits.max - boundaryBuffer)
            let isApproachingBottom = targetCalendarOffset < (limits.min + boundaryBuffer)
            
            if isApproachingTop || isApproachingBottom {
                let clampedTarget = max(limits.min, min(limits.max, targetCalendarOffset))
                
                if isApproachingTop && targetCalendarOffset > limits.max {
                    let overshoot = targetCalendarOffset - limits.max
                    let dampenedOvershoot = overshoot * 0.3
                    let smoothTarget = limits.max + dampenedOvershoot
                    targetContentOffset.pointee.y = parent.centerY - smoothTarget
                } else if isApproachingBottom && targetCalendarOffset < limits.min {
                    let overshoot = limits.min - targetCalendarOffset
                    let dampenedOvershoot = overshoot * 0.3
                    let smoothTarget = limits.min - dampenedOvershoot
                    targetContentOffset.pointee.y = parent.centerY - smoothTarget
                } else {
                    let correctedPhysicalY = parent.centerY - clampedTarget
                    targetContentOffset.pointee.y = correctedPhysicalY
                }
                
                scrollView.decelerationRate = UIScrollView.DecelerationRate.fast
            } else {
                scrollView.decelerationRate = UIScrollView.DecelerationRate.normal
            }
        }
    }
}
