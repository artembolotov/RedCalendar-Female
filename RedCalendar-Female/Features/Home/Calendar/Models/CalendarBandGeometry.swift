//
//  CalendarBandGeometry.swift
//  RedCalendar-Female
//

import SwiftUI

// The top band's measurements, the two masks that carve the screen along them, and the wash
// that stands between.
//
// It exists as one value because three things now have to agree on it exactly: the layer that
// blurs the calendar into the band, the wash that takes the colour out of what is blurred, and
// the strip of weekday labels standing on both. The labels sit against the bottom of the bar,
// and blur and wash have to reach precisely that far before they begin dissolving — a few
// points of disagreement and the labels drift into the dissolve, or the wash ends a hair short
// of the blur and leaves a bright line across the band.
struct CalendarBandGeometry {
    /// Status bar plus navigation bar — everything above the weekday strip.
    let topInset: CGFloat

    /// Down to the bottom of the weekday strip: what the calendar has to clear, and how far
    /// the blur holds at full strength.
    var barHeight: CGFloat {
        topInset + CalendarConstants.weekdaysHeaderHeight
    }

    /// Opaque across the bar, gone by the bottom of the dissolve, absent for the rest of the
    /// screen. Worn by the blurred copy of the grid.
    ///
    /// Built out of fixed heights rather than gradient stops at fractions: a mask is stretched
    /// to the frame of whatever it masks, and these mask the full-screen grid — proportional
    /// stops would smear the band across the whole page.
    var mask: some View {
        band(above: .black, below: .clear)
    }

    /// The exact complement, worn by the sharp grid.
    ///
    /// The sharp layer has to be *erased* under the band rather than merely covered. Leaving it
    /// beneath the blurred copy would show both at once — crisp numerals inside a soft halo of
    /// themselves. Because the two alphas sum to one at every height, the dissolve is an honest
    /// crossfade of a single image from blurred to sharp: no seam, no doubling, and no dip in
    /// brightness through the middle.
    var inverseMask: some View {
        band(above: .clear, below: .black)
    }

    /// The wash laid over the blurred copy: the page's own colour, solid across the bar and
    /// gone by the bottom of the same dissolve.
    ///
    /// It is only as tall as the band. A full-height layer with a transparent tail would be
    /// simpler to write and would swallow every tap on the calendar — `Color.clear` is hit
    /// tested like any other shape.
    ///
    /// The ramp ends on the same colour at zero alpha rather than on `.clear`, which is not the
    /// same thing: interpolating toward `.clear` runs the midpoint through an unpremultiplied
    /// black, and a wash that goes grey through its middle is exactly the plate being avoided.
    var scrim: some View {
        let wash = Color("AppBackgroundColor").opacity(CalendarConstants.topChromeScrimOpacity)

        return VStack(spacing: 0) {
            wash
                .frame(height: barHeight)

            LinearGradient(
                colors: [wash, wash.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: CalendarConstants.topChromeFadeHeight)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Private

    private func band(above: Color, below: Color) -> some View {
        VStack(spacing: 0) {
            above
                .frame(height: barHeight)

            LinearGradient(colors: [above, below], startPoint: .top, endPoint: .bottom)
                .frame(height: CalendarConstants.topChromeFadeHeight)

            below
        }
    }
}
