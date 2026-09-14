//
//  DayCardNavigationComponents.swift
//  RedCalendar-Female
//

import SwiftUI

/// A screen pushed inside the day card, over its root content or over another pushed screen.
/// The pager owns the transitions — it is the one holding the window's pan recognizer, which
/// drives the interactive swipe back.
enum DayCardRoute: Hashable {
    case flowLevel
    case ovulation
    case ovulationManualDay
}

/// Where each layer of the card's navigation stack sits during a push or a swipe back. Depth 0 is
/// the card's root content, depth `pushedCount` the top screen.
struct DayCardLayers {
    let pushedCount: Int
    // The top screen's transition: 0 is off the card's trailing edge, 1 at rest.
    let progress: CGFloat
    let cardWidth: CGFloat

    private let underlayParallax: CGFloat = 0.3

    // The top screen slides in from the trailing edge; the one under it slides a third of the way
    // out, as a navigation controller's does; anything deeper stays where that left it.
    func offset(depth: Int) -> CGFloat {
        let top = pushedCount
        if depth == top && top > 0 {
            return cardWidth * (1 - progress)
        }
        if depth == top - 1 {
            return -cardWidth * underlayParallax * progress
        }
        return depth < top ? -cardWidth * underlayParallax : 0
    }

    func isTop(depth: Int) -> Bool {
        let top = pushedCount
        guard top > 0 else { return depth == 0 }
        return progress > 0.5 ? depth == top : depth == top - 1
    }
}

/// The card's close button. Drawn above every layer and outside the slide, so it stays put
/// through a push and a swipe back. Whatever slides under it dissolves into a disc of the card's
/// own colour rather than being cut by the glyph's edge; at rest nothing is under it and the disc
/// is invisible.
struct DayCardCloseButton: View {
    let size: CGFloat
    let backgroundColor: Color
    let action: () -> Void

    private let plateRadius: CGFloat = 26

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: backgroundColor, location: 0),
                                .init(color: backgroundColor, location: 0.55),
                                .init(color: backgroundColor.opacity(0), location: 1)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: plateRadius
                        )
                    )
                    .frame(width: plateRadius * 2, height: plateRadius * 2)

                // A plain glyph on a quiet disc, as the system's own close button draws it — the
                // filled `xmark.circle.fill` symbol read a generation older than the card around it.
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: size, height: size)
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(width: size, height: size)
            .tapTargetMargin(DayDetailsMetrics.closeButtonTapMargin)
        }
        .accessibilityLabel(Text("Common.Close"))
    }
}

/// The title row of a screen pushed inside the day card (see `DayCardRoute`): back, the screen's
/// name, and room for the close button, which the card draws over every screen itself.
struct DayCardPushedHeader: View {
    @EnvironmentObject var store: AppStore
    let title: LocalizedStringKey
    @Binding var path: [DayCardRoute]
    let trailingControlWidth: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Button(action: goBack) {
                Image(systemName: "chevron.backward")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(store.state.accentTheme.accent)
                    .frame(width: trailingControlWidth, height: trailingControlWidth, alignment: .leading)
            }
            .accessibilityLabel(Text("Common.Back"))

            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Color.clear
                .frame(width: trailingControlWidth, height: trailingControlWidth)
        }
    }

    private func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

/// The chevron a table cell draws for a row that opens another screen — on every row in the day
/// card that pushes, and on no row that commits in place.
struct DisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.forward")
            .font(.body.weight(.semibold))
            .imageScale(.small)
            .foregroundColor(Color(UIColor.tertiaryLabel))
            .accessibilityHidden(true)
    }
}
