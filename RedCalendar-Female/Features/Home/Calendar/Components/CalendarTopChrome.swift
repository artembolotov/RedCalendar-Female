//
//  CalendarTopChrome.swift
//  RedCalendar-Female
//

import SwiftUI

// The band the calendar scrolls under: the navigation bar's height, the weekday strip, and
// a lower edge that dissolves instead of ending.
//
// iOS 26 draws this for itself — `.scrollEdgeEffectStyle(.soft, for: .top)` over a bar in
// `.safeAreaBar(edge: .top)`. Neither reaches us: both attach to a SwiftUI `ScrollView`, and
// the calendar's scrolling is a bare `UIScrollView` inside `InfiniteScrollContainer` whose
// content is empty — everything visible is `CalendarGridView`, a separate layer slid over it
// with `.offset`. There is nothing for the system effect to find, let alone blur.
//
// So the band is drawn here, and that is what makes the answer for older systems trivial:
// `.ultraThinMaterial` behind a gradient mask is iOS 15 API, one implementation with no
// version branch at all.
struct CalendarTopChrome: View {
    let weekdays: [String]
    var weekendIndices: Set<Int> = []
    let width: CGFloat
    /// Status bar plus navigation bar — everything above the weekday strip that the grid now
    /// runs underneath.
    let topInset: CGFloat
    let onTap: () -> Void

    /// What the calendar has to clear. The fade below it hangs over live rows and is not part
    /// of the space the content is centred against.
    private var barHeight: CGFloat {
        topInset + CalendarConstants.weekdaysHeaderHeight
    }

    private var totalHeight: CGFloat {
        barHeight + CalendarConstants.topChromeFadeHeight
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            backdrop
                .frame(height: totalHeight)
                // The fade sits over days that are still legible; a tap there belongs to the
                // day under it, not to the band.
                .allowsHitTesting(false)

            CalendarHeaderView(
                weekdays: weekdays,
                weekendIndices: weekendIndices,
                width: width,
                height: CalendarConstants.weekdaysHeaderHeight
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .frame(height: barHeight)
            // The scroll view reaches under the navigation bar now. Without a hit area over
            // the whole bar, a tap beside the menu button would select a day hidden behind it
            // rather than dismiss the day card — which is what tapping the strip has always done.
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
    }

    // MARK: - Private Views

    private var backdrop: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            // Blur alone does not reliably separate the labels from a solid period bar
            // passing under them: the material takes its lightness from whatever is behind it,
            // and a full-strength accent red is not light. The page colour over it fixes the
            // density the labels sit on.
            .overlay(Color("AppBackgroundColor").opacity(CalendarConstants.topChromeTintOpacity))
            .mask { fadeMask }
    }

    // Masking a material fades its *alpha*, not its blur radius — a radius that ramps down
    // the gradient would need a private `CAFilter`, which cannot ship. Over a grid that is
    // moving anyway the two are hard to tell apart, and this one costs nothing.
    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: fadeStart),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var fadeStart: CGFloat {
        guard totalHeight > 0 else { return 1 }
        return barHeight / totalHeight
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

        CalendarTopChrome(
            weekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"],
            weekendIndices: [5, 6],
            width: 375,
            topInset: 100,
            onTap: {}
        )
    }
    .ignoresSafeArea()
}
