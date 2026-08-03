//
//  CalendarBandGeometry.swift
//  RedCalendar-Female
//

import SwiftUI

// The top band's measurements, the mask that carves the screen along them, and the wash that
// stands between.
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

    /// How much of the grid the blurred copy keeps before it is blurred.
    ///
    /// The crop is what keeps the copy affordable: a blur is computed for the whole layer it
    /// is given, *before* the mask cuts the band out of it, so an uncropped copy pays for a
    /// full-screen gaussian per frame of scroll. Cut down to the band first, it blurs a strip
    /// a fraction of that size.
    ///
    /// Two radii past the mask's own reach, because a blur samples beyond its input's edge:
    /// the bottom of the crop dissolves toward transparent for about that far, and the margin
    /// puts every darkened pixel where the mask's alpha is already zero.
    var blurCropHeight: CGFloat {
        barHeight + CalendarConstants.topChromeFadeHeight + CalendarConstants.topChromeBlurRadius * 2
    }

    /// Opaque across the bar, gone by the bottom of the dissolve, absent for the rest of the
    /// screen. Worn by the blurred copy of the grid, which is the only thing that wears a mask
    /// here.
    ///
    /// The sharp grid used to wear the exact complement of this, so that the two alphas summed
    /// to one and the dissolve was an honest crossfade of a single image rather than crisp
    /// numerals inside a soft halo of themselves. That complement is gone, and the property is
    /// not coming back: it was a gradient mask over a full-screen layer, which is a
    /// screen-sized offscreen pass per frame of scroll. The blurred copy is drawn on the page's
    /// own gradient instead — opaque, so compositing it at alpha `a` produces the identical
    /// crossfade with nothing showing through. See `CalendarView.blurredBandLayer`.
    ///
    /// Built out of fixed heights rather than gradient stops at fractions: a mask is stretched
    /// to the frame of whatever it masks, and proportional stops would land at different
    /// heights on a layer cropped to `blurCropHeight` than on one cropped anywhere else. The
    /// fixed heights are what let the dissolve stay put whatever the crop.
    var mask: some View {
        VStack(spacing: 0) {
            Color.black
                .frame(height: barHeight)

            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: CalendarConstants.topChromeFadeHeight)

            Color.clear
        }
    }

    /// The wash laid over the blurred copy: the page's own colour, densest at the top of the
    /// screen, thin by the bottom of the bar, gone by the bottom of the dissolve.
    ///
    /// The density gradient is what is left of the blur ramp — the wash grows toward the top
    /// the way a variable blur's radius would, hiding shapes behind the navigation bar where
    /// a heavier radius used to, at no per-frame cost. See the scrim opacities in
    /// `CalendarConstants` for why the ramp lives here and not in the blur.
    ///
    /// It is only as tall as the band. A full-height layer with a transparent tail would be
    /// simpler to write and would swallow every tap on the calendar — `Color.clear` is hit
    /// tested like any other shape.
    ///
    /// Every ramp runs between the same colour at two alphas rather than to `.clear`, which is
    /// not the same thing: interpolating toward `.clear` runs the midpoint through an
    /// unpremultiplied black, and a wash that goes grey through its middle is exactly the
    /// plate being avoided.
    var scrim: some View {
        let wash = Color("AppBackgroundColor")
        let top = wash.opacity(CalendarConstants.topChromeScrimOpacityTop)
        let bottom = wash.opacity(CalendarConstants.topChromeScrimOpacityBottom)

        return VStack(spacing: 0) {
            LinearGradient(
                colors: [top, bottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: barHeight)

            LinearGradient(
                colors: [bottom, wash.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: CalendarConstants.topChromeFadeHeight)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
}
