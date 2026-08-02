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
// The track is backed by the page's own colour, with a translucent fill laid over it. The fill
// alone let everything under the band show through the capsule, so its tone swam with whatever
// happened to be scrolling past and day numbers ghosted in between the labels — the App Store
// Connect control this echoes never fights its own background. The backing is the page colour
// and not an opaque grey for the same reason the scrim is: over the empty page it *is* the
// page, so the capsule reads as one quiet object rather than a plate, and only where content
// passes does it actually hide anything.
//
// Three layers, and the third is the price of the first two being thin. The backing is held at
// `weekdaysBarBackingOpacity` rather than full — enough to keep a period bar from arriving as a
// red shape, not so much that the track stops belonging to the band it stands on. What that
// costs is the capsule's own edge: an opaque fill draws its boundary with the density step
// against the page, and thinning the fill thins the step. So the shape is stated by a hairline
// instead, and the outline is what lets the fill go as light as it does. Lightening the fill
// without it just dissolves the track.
//
// The fill and the rim are the ⋯ menu button's, brought over deliberately so the two pieces of
// chrome over this calendar read as one material: white fill, white rim. What could not come
// over is the material itself. `HomeMenuView` uses `.ultraThinMaterial` (and the system's glass
// above iOS 26), and a material is a backdrop capture per frame — over a ⌀36 button that is
// nothing, over a 370pt strip standing on an already-blurred band it is a second full-width
// capture on every frame of a scroll, which is the same budget `topChromeBlurRadius` is held to
// one radius by. Plain colours cost nothing and land in the same place.
//
// The rim is white in the dark theme only. On the near-white page a white rim draws literally
// nothing, so the light theme's is a faint neutral instead — the one place the analogy had to
// be translated rather than copied. It is the fill that carries "light" in that theme, and it
// carries it against the content passing under rather than against the page.
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
    // The track is translucent now, so previewing it over nothing says nothing. A bar under it
    // is the case the backing opacity was chosen against.
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
