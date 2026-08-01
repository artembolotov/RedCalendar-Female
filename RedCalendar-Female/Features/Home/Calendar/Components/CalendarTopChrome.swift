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
// a `Material` behind a gradient mask is iOS 15 API, one implementation with no version
// branch at all.
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

    // The thinnest material there is, and the band should stay at the thin end of the range.
    //
    // `.bar` sat here first, on the reasoning that this band stands in for a navigation bar so
    // it should be made of the bar's own `systemChromeMaterial`. That is the wrong instinct
    // for what the band is for: chrome material exists to make bar *contents* legible, which
    // it does by hiding what passes behind them. Here the whole point is that the calendar
    // stays visible — a day going under the band should soften, not vanish — so the material
    // is chosen for how little it takes away, not for which surface it imitates.
    //
    // Nothing is painted over it either. A flat colour laid on a material for extra density is
    // what turns glass back into a plate: a material's density arrives *with* diffusion, so
    // shapes and colour still come through, while paint's density arrives with nothing and
    // only flattens the contrast.
    //
    // There is nothing thinner in `Material`. If the band still hides too much, the next lever
    // is a `UIVisualEffectView` held at partial `fractionComplete` by a paused
    // `UIViewPropertyAnimator` — the public way to ask for a fraction of a blur — not another
    // step through the material scale, which stops here.
    private var backdrop: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask { fadeMask }
    }

    // Masking a material fades its *alpha*, not its blur radius — a radius that ramps down
    // the gradient would need a private `CAFilter`, which cannot ship.
    //
    // With nothing painted over the material, the two are close: what fades out along the
    // gradient is the frosting itself, so a day passing through simply sharpens. It was the
    // paint that made the difference visible, because fading paint *erases* rather than
    // clarifies — the row of numerals at the edge came out cut in half.
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
