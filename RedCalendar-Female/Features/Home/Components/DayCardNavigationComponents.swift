//
//  DayCardNavigationComponents.swift
//  RedCalendar-Female
//

import SwiftUI

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
