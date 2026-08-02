//
//  CalendarHeaderView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI

// The weekday labels on a track, and nothing else. The strip no longer draws a divider under
// itself: it now sits on `CalendarTopChrome`'s blurred band, and the band's dissolving lower
// edge is the boundary. A hairline over a blur reads as window chrome — exactly the flat plate
// the band exists to get rid of.
//
// The track is a capsule in a neutral fill, so the row of labels reads as one object rather
// than seven loose words. Its measurements come off App Store Connect's segmented control: a
// 32pt track whose corner is an exact capsule arc, and labels at about 13pt. What is
// deliberately not taken is everything that control does per segment — no dividers, no pill, no
// column singled out for any reason. Every weekday is drawn identically; the strip is a legend
// for the grid, and a legend that emphasises one of its own entries is telling you about
// itself. The labels also stay on the day columns rather than being spaced by the container,
// for the same reason: they belong to the grid below, not to the track around them.
//
// It used to borrow the period bar's height and radius to say "the same shape as the period
// bar". At 30pt against the bar's 22 it no longer says that, so the radius follows the height
// instead — see `weekdaysTrackHeight`.
//
// Its width is the seven columns exactly, not the view: `ViewportCalculator` places day cells
// off the same `horizontalPadding`, so the track starts where Monday's column starts and ends
// where Sunday's ends. Anything wider and the bar would overhang the calendar it labels.
//
// The track is solid: the page's own colour at `weekdaysBarBackingOpacity`, then the fill that
// gives it its tone. It spent a while translucent, letting a period bar cross under it as a pale
// pink, and that is deliberately over — the bar now stops dead at the capsule's edge.
//
// In the light theme the fill is the ⋯ button's white, translated into this page's key rather
// than copied off a screenshot. The distinction is the whole of it, and it is measurable. A real
// iOS circular button on App Store Connect's own page is (255,255,255) on (233,233,238): white,
// 22 levels clear of its background, and slightly cool because that page is a cool grey. Our
// page is (251,249,249) — warm, and already almost white. Copying the literal white gives 4
// levels instead of 22, and gives them in the wrong direction of hue: a cold patch on a warm
// page, which reads as a foreign object rather than as a surface lifted off it.
//
// So the fill is (255,253,253): the page's own colour raised 4 levels with its warmth intact —
// R−G is 2 on both. It is the same *relationship* the button has, which is what the analogy was
// ever about; the identical number was never available on a page this light.
//
// Four levels is a tone, not an edge, so the rim draws the capsule and the rim alone — which is
// why the light one is stronger than the dark theme's needs to be, and why it is warm-neutral
// too. A cool grey hairline on a warm page is the same mistake as the cold fill, just thinner.
//
// Full opacity rather than a high alpha, and the difference is visible. At 0.55 the three
// percent of calendar getting past `weekdaysBarBackingOpacity` still tinted the track where a
// period bar crossed under it — two or three levels, but a coloured two or three, sitting in a
// field of flat near-white. At 1.0 the bar is simply gone, and the backing stops mattering in
// this theme at all; it is the dark theme's white lift, at 0.13, that still leans on it.
//
// The dark theme is unchanged. Opacity was never what made it read: white at 0.13 over a
// near-black page is the same light grey either way.
//
// The rim is the ⋯ menu button's, and it is white in the dark theme only. On the near-white page
// a white rim draws literally nothing, so the light theme's is a faint neutral instead — the one
// place the analogy had to be translated rather than copied. What could not come over at all is
// the material: `HomeMenuView` uses `.ultraThinMaterial` (and the system's glass above iOS 26),
// and a material is a backdrop capture per frame — over a ⌀36 button that is nothing, over a
// 370pt strip standing on an already-blurred band it is a second full-width capture on every
// frame of a scroll, which is the same budget `topChromeBlurRadius` is held to one radius by. A
// solid track has no use for one anyway.
struct CalendarHeaderView: View {
    let weekdays: [String]
    let width: CGFloat
    let height: CGFloat

    // MARK: - Constants
    private let horizontalPadding: CGFloat = CalendarConstants.horizontalPadding

    // The first layout pass can hand in a zero width, making `width - horizontalPadding`
    // negative — an invalid frame dimension.
    private var trackWidth: CGFloat {
        max(0, width - horizontalPadding)
    }

    private var columnWidth: CGFloat {
        trackWidth / 7
    }

    private func columnX(_ index: Int) -> CGFloat {
        horizontalPadding / 2 + CGFloat(index) * columnWidth
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            track
            labels
        }
        .frame(width: width, height: height)
    }

    // MARK: - Layers

    private var track: some View {
        Capsule()
            .fill(
                Color("AppBackgroundColor")
                    .opacity(CalendarConstants.weekdaysBarBackingOpacity)
            )
            .overlay(Capsule().fill(Color("WeekdaysBarColor")))
            .overlay(
                Capsule().strokeBorder(
                    Color("WeekdaysBarStrokeColor"),
                    lineWidth: CalendarConstants.weekdaysBarStrokeWidth
                )
            )
            .frame(width: trackWidth, height: CalendarConstants.weekdaysTrackHeight)
            .position(x: width / 2, y: height / 2)
    }

    private var labels: some View {
        ForEach(Array(weekdays.enumerated()), id: \.offset) { dayIndex, weekday in
            Text(weekday)
                // 13pt, the reference's own size, now that the track is tall enough to carry
                // it. At the old 12 on a 30pt track the labels floated in the middle of far
                // too much fill.
                .font(.footnote)
                // Primary at semibold, not secondary at heavy: the strip stands on a
                // translucent track over scrolling content, and a grey label over a grey
                // track over a moving page was the first thing to vanish. Contrast is
                // what carries the visibility — primary at heavy read as shouting.
                //
                // One weight and one colour for all seven. No weekend variant, no marker on
                // today: the labels are a legend, and nothing about which column you are
                // looking at should change how the legend is drawn.
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .position(x: columnX(dayIndex) + columnWidth / 2, y: height / 2)
        }
    }
}

#Preview {
    // Two things are being checked at once, and the bar under the track is what shows both: that
    // it is cut off cleanly at the capsule rather than ghosting through, and that the track is
    // still findable over the stretch of plain page either side of it.
    ZStack {
        Color("AppBackgroundColor")

        Capsule()
            .fill(AccentTheme.coral.accent)
            .frame(height: CalendarConstants.periodBarHeight)
            .padding(.horizontal, CalendarConstants.horizontalPadding)

        CalendarHeaderView(
            weekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"],
            width: 375,
            height: CalendarConstants.weekdaysHeaderHeight
        )
    }
    .frame(height: 120)
}
