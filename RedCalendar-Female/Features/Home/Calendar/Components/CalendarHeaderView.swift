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
// The track is the same shape as the period bar — `periodBarHeight`, `periodBarCornerRadius`,
// `.continuous` — in a neutral fill instead of the accent, so the row of labels reads as one
// object rather than seven loose words. It is the App Store Connect segmented control's
// concept without its mechanics: a container, no selection, no dividers, and the labels stay
// where the day columns are rather than being spaced by the container.
//
// Its width is the seven columns exactly, not the view: `ViewportCalculator` places day cells
// off the same `horizontalPadding`, so the track starts where Monday's column starts and ends
// where Sunday's ends. Anything wider and the bar would overhang the calendar it labels.
//
// The track is backed by the page's own colour, with the translucent grey laid over it. The
// grey alone let everything under the band show through the capsule, so its tone swam with
// whatever happened to be scrolling past and day numbers ghosted in between the labels — the
// App Store Connect control this echoes never fights its own background. The backing is the
// page colour and not an opaque grey for the same reason the scrim is: over the empty page it
// *is* the page, so the capsule reads as one quiet object rather than a plate, and only where
// content passes does it actually hide anything.
//
// Three layers, and the third is the price of the first two being thin. The backing is held at
// `weekdaysBarBackingOpacity` rather than full — enough to keep a period bar from arriving as a
// red shape, not so much that the track stops belonging to the band it stands on — and the grey
// over it is lighter than it once was. What that costs is the capsule's own edge: an opaque fill
// draws its boundary with the density step against the page, and thinning the fill thins the
// step. So the shape is stated by a hairline instead, and the outline is what lets the fill go
// as light as it does. Lightening the grey without it just dissolves the track.
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: CalendarConstants.periodBarCornerRadius,
                style: .continuous
            )
            .fill(
                Color("AppBackgroundColor")
                    .opacity(CalendarConstants.weekdaysBarBackingOpacity)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: CalendarConstants.periodBarCornerRadius,
                    style: .continuous
                )
                .fill(Color("WeekdaysBarColor"))
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: CalendarConstants.periodBarCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    Color("WeekdaysBarStrokeColor"),
                    lineWidth: CalendarConstants.weekdaysBarStrokeWidth
                )
            )
            .frame(width: trackWidth, height: CalendarConstants.periodBarHeight)
            .position(x: width / 2, y: height / 2)

            ForEach(Array(weekdays.enumerated()), id: \.offset) { dayIndex, weekday in
                let dayWidth = trackWidth / 7
                let dayX = horizontalPadding / 2 + CGFloat(dayIndex) * dayWidth
                let centerX = dayX + dayWidth / 2

                Text(weekday)
                    .font(.caption)
                    // Primary at semibold, not secondary at heavy: the strip stands on a
                    // translucent track over scrolling content, and a grey label over a grey
                    // track over a moving page was the first thing to vanish. Contrast is
                    // what carries the visibility — primary at heavy read as shouting.
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .position(x: centerX, y: height / 2)
            }
        }
        .frame(width: width, height: height)
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
