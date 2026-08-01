//
//  CalendarBandGeometry.swift
//  RedCalendar-Female
//

import SwiftUI

// The top band's measurements and the two masks that carve the screen along them.
//
// It exists as one value because two things now have to agree on it exactly: the layer that
// blurs the calendar into the band, and the strip of weekday labels standing on it. The labels
// sit against the bottom of the bar, and the blur has to reach precisely that far before it
// begins dissolving — a few points of disagreement and the labels drift into the dissolve.
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
