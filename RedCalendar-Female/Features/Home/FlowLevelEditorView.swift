//
//  FlowLevelEditorView.swift
//  RedCalendar-Female
//

import SwiftUI

// Pushed inside the day card from `DayDetailsView.flowLevelRow` (see `DayCardRoute`). Every
// option commits on the tap that chose it and goes back to the card — a flow level is one value
// out of four, and there is nothing to confirm about it.
struct FlowLevelEditorView: View {
    @EnvironmentObject var store: AppStore
    let dayStamp: Daystamp
    @Binding var path: [DayCardRoute]
    let trailingControlWidth: CGFloat

    // Set on the tap itself, so the checkmark lands on the chosen row while the screen slides
    // away — the stored level comes back through the database observation a moment later. Read
    // from the store until then rather than seeded in `onAppear`, which a screen entering from
    // past the card's edge only receives once the slide is well under way.
    @State private var chosenLevel: Int??

    private var selection: Int? {
        chosenLevel ?? store.state.calendarState.flowLevels[dayStamp]
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DayCardPushedHeader(
                title: "DayDetails.Flow.Title",
                path: $path,
                trailingControlWidth: trailingControlWidth
            )

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(FlowLevelOption.all.enumerated()), id: \.offset) { index, level in
                    if index > 0 {
                        Divider()
                    }
                    optionRow(level: level)
                }
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Rows

    private func optionRow(level: Int?) -> some View {
        let isSelected = selection == level

        return Button {
            chosenLevel = .some(level)
            store.send(.data(.setFlowLevel(dayStamp, level)))
            path = []
        } label: {
            HStack {
                Text(FlowLevelOption.label(for: level))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(store.state.accentTheme.accent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DayDetailsMetrics.valueRowVerticalPadding)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
