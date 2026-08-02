//
//  CalendarTopChrome.swift
//  RedCalendar-Female
//

import SwiftUI

// What stands on the top band: the weekday labels, and the hit area covering the bar.
//
// It draws no backdrop of its own, and that is the point the band took three attempts to
// reach. A `Material` here only ever became a plate, because a material over this calendar is
// mostly a material over *empty page* — the grid is sparse, one row of days and a lot of air,
// and with nothing behind it to diffuse a material can show only its own grey. The band is
// made instead out of the calendar itself: blurred in `CalendarView.blurredBandLayer`, then
// washed toward the page colour by `CalendarBandGeometry.scrim`. Neither has anything to act
// on where there is no content, so over empty page the band simply is not there — which is the
// one thing a material could never manage. See `CalendarBandGeometry` for the measurements the
// three of them share.
//
// iOS 26 would do all of this for us — `.scrollEdgeEffectStyle(.soft, for: .top)` over a bar
// in `.safeAreaBar(edge: .top)` — but neither reaches us: both attach to a SwiftUI
// `ScrollView`, and the calendar's scrolling is a bare `UIScrollView` inside
// `InfiniteScrollContainer` whose content is empty. Everything visible is `CalendarGridView`,
// a separate layer slid over it with `.offset`. There is nothing there for the system effect
// to find, let alone blur — and drawing it ourselves is what leaves iOS 15.4 with the same
// treatment as iOS 26, with no version branch anywhere.
struct CalendarTopChrome: View {
    let weekdays: [String]
    let width: CGFloat
    /// Status bar plus navigation bar — everything above the weekday strip that the grid now
    /// runs underneath.
    let topInset: CGFloat
    let onTap: () -> Void

    private var band: CalendarBandGeometry {
        CalendarBandGeometry(topInset: topInset)
    }

    // MARK: - Body

    var body: some View {
        CalendarHeaderView(
            weekdays: weekdays,
            width: width,
            height: CalendarConstants.weekdaysHeaderHeight
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
        .frame(height: band.barHeight)
        // The scroll view reaches under the navigation bar now. Without a hit area over the
        // whole bar, a tap beside the menu button would select a day hidden behind it rather
        // than dismiss the day card — which is what tapping the strip has always done.
        //
        // The hit area stops at the bar. Below it lies the dissolve, where days are already
        // half in focus and plainly readable; a tap there belongs to the day under it.
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ZStack(alignment: .top) {
        LinearGradient(
            colors: [Color("AppBackgroundColor"), Color("AppBackgroundEdgeColor")],
            startPoint: .top,
            endPoint: .bottom
        )

        VStack(spacing: 12) {
            ForEach(0..<12, id: \.self) { _ in
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { _ in
                        Capsule()
                            .fill(AccentTheme.coral.accent)
                            .frame(height: 22)
                    }
                }
            }
        }
        .padding(.horizontal, CalendarConstants.horizontalPadding / 2)
        .padding(.top, 60)

        // Stood in for the layers `CalendarView` puts under the strip, so the labels are
        // previewed against something like the ground they actually stand on.
        CalendarBandGeometry(topInset: 100).scrim

        CalendarTopChrome(
            weekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"],
            width: 375,
            topInset: 100,
            onTap: {}
        )
    }
    .ignoresSafeArea()
}
