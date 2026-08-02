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
// Solidity moves where the shape comes from, and that is the part worth keeping straight. A
// see-through track has to be outlined or it dissolves; a solid one draws its own boundary with
// the step between its fill and the page, and the rim only sharpens what is already there. So
// the fill is now the whole design and the rim is trim.
//
// Which is why the light theme's fill is a light cool grey and not white. White was right while
// the track was see-through — it lightened whatever passed under it, and *that* was what made
// the capsule visible. Solid, it has nothing left to lighten, and white on a near-white page is
// a shape you cannot find: 2 levels of separation, with the whole capsule carried by a hairline.
// The fill instead sits 13 levels under the page, which is the relationship App Store Connect's
// own control has with its own background (#E4E4E9 on #F1F1F5, 16 levels) — light, but present.
//
// The dark theme keeps its white lift and its white rim unchanged, because opacity was never
// what made it read: white at 0.13 over a near-black page is a light grey either way.
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
